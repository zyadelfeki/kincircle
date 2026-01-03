import * as functions from 'firebase-functions';

export const retrainAnomalyModel = functions.pubsub
  .topic('retrain-anomaly-model')
  .onPublish(async () => {
    console.log('Retrain trigger received');
    // Placeholder – you could invoke Vertex Pipeline, or submit AutoML job via REST.
    // For POC we just log. Real implementation should mirror commands in docs.
  }); 