import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// Cloud Function to handle cascading deletes when a client is deleted
export const deleteClientCascade = functions.firestore
  .document('users/{userId}')
  .onDelete(async (snap, context) => {
    const userData = snap.data();
    const userId = context.params.userId;

    // Only process if this was a client
    if (userData.role !== 'client') {
      return null;
    }

    console.log(`Cascading delete for client: ${userId}`);

    const batch = db.batch();

    try {
      // Delete client document
      const clientRef = db.collection('clients').doc(userId);
      batch.delete(clientRef);

      // Delete all routines for this client
      const routinesSnapshot = await db
        .collection('routines')
        .where('clientId', '==', userId)
        .get();

      routinesSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      // Commit batch delete
      await batch.commit();

      // Delete Firebase Auth user (this requires admin privileges)
      try {
        await auth.deleteUser(userId);
        console.log(`Successfully deleted auth user: ${userId}`);
      } catch (error) {
        console.error(`Error deleting auth user ${userId}:`, error);
        // Continue even if auth deletion fails
      }

      console.log(`Cascade delete completed for client: ${userId}`);
      return null;
    } catch (error) {
      console.error(`Error in cascade delete for client ${userId}:`, error);
      throw error;
    }
  });

// Cloud Function to handle routine cleanup when client is deleted
export const cleanupClientRoutines = functions.https.onCall(async (data, context) => {
  // Verify the caller is authenticated and is a trainer
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { clientId } = data;
  
  if (!clientId) {
    throw new functions.https.HttpsError('invalid-argument', 'clientId is required');
  }

  try {
    // Verify the caller is a trainer and has permission to delete this client
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const callerData = callerDoc.data();

    if (!callerData || callerData.role !== 'trainer') {
      throw new functions.https.HttpsError('permission-denied', 'Only trainers can delete clients');
    }

    // Verify the client belongs to this trainer
    const clientDoc = await db.collection('clients').doc(clientId).get();
    const clientData = clientDoc.data();

    if (!clientData || clientData.trainerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Client does not belong to this trainer');
    }

    const batch = db.batch();

    // Delete client document
    const clientRef = db.collection('clients').doc(clientId);
    batch.delete(clientRef);

    // Delete user document
    const userRef = db.collection('users').doc(clientId);
    batch.delete(userRef);

    // Delete all routines for this client
    const routinesSnapshot = await db
      .collection('routines')
      .where('clientId', '==', clientId)
      .get();

    routinesSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // Commit batch delete
    await batch.commit();

    // Delete Firebase Auth user
    try {
      await auth.deleteUser(clientId);
      console.log(`Successfully deleted auth user: ${clientId}`);
    } catch (error) {
      console.error(`Error deleting auth user ${clientId}:`, error);
      // Continue even if auth deletion fails
    }

    return { success: true, message: 'Client successfully deleted' };
  } catch (error) {
    console.error(`Error deleting client ${clientId}:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to delete client');
  }
});

// Cloud Function for email notifications
export const sendCustomEmail = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { to, subject, body, type } = data;

  if (!to || !subject || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required email fields');
  }

  try {
    // Here you would integrate with your email service (SendGrid, SES, etc.)
    // For now, we'll just log the email
    console.log(`Sending ${type} email to ${to}: ${subject}`);
    console.log(`Body: ${body}`);

    // TODO: Implement actual email sending
    // Example with SendGrid:
    // const sgMail = require('@sendgrid/mail');
    // sgMail.setApiKey(process.env.SENDGRID_API_KEY);
    // await sgMail.send({ to, from: 'noreply@fitfusion.app', subject, html: body });

    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// Cloud Function to generate analytics data
export const generateAnalytics = functions.https.onCall(async (data, context) => {
  // Verify authentication and admin role
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const callerData = callerDoc.data();

    // Only trainers can access analytics for their data
    if (!callerData || callerData.role !== 'trainer') {
      throw new functions.https.HttpsError('permission-denied', 'Only trainers can access analytics');
    }

    const trainerId = context.auth.uid;

    // Get trainer's clients
    const clientsSnapshot = await db
      .collection('clients')
      .where('trainerId', '==', trainerId)
      .get();

    // Get trainer's routines
    const routinesSnapshot = await db
      .collection('routines')
      .where('trainerId', '==', trainerId)
      .get();

    // Calculate analytics
    const clientCount = clientsSnapshot.docs.length;
    const routineCount = routinesSnapshot.docs.length;
    const publicRoutineCount = routinesSnapshot.docs.filter(
      doc => doc.data().isPublic === true
    ).length;

    // Recent activity (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentRoutines = routinesSnapshot.docs.filter(
      doc => doc.data().createdAt?.toDate() > thirtyDaysAgo
    ).length;

    return {
      clientCount,
      routineCount,
      publicRoutineCount,
      privateRoutineCount: routineCount - publicRoutineCount,
      recentRoutines,
      generatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
  } catch (error) {
    console.error('Error generating analytics:', error);
    throw new functions.https.HttpsError('internal', 'Failed to generate analytics');
  }
});

// Cloud Function to cleanup expired public tokens
export const cleanupExpiredTokens = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  console.log('Starting cleanup of expired public tokens');

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Find routines with expired public tokens
    const expiredSnapshot = await db
      .collection('routines')
      .where('isPublic', '==', true)
      .where('publicExpiresAt', '<', now)
      .get();

    if (expiredSnapshot.empty) {
      console.log('No expired tokens found');
      return null;
    }

    const batch = db.batch();

    expiredSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isPublic: false,
        publicToken: admin.firestore.FieldValue.delete(),
        publicExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    console.log(`Cleaned up ${expiredSnapshot.docs.length} expired tokens`);
    return null;
  } catch (error) {
    console.error('Error cleaning up expired tokens:', error);
    throw error;
  }
});

// Health check function for monitoring
export const healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});