import tensorflow as tf

# Simple dense model mapping N features to 3 outputs.
# This is a placeholder for demo/testing. Replace with a real trained model later.

def build_model(input_dim=12):
    i = tf.keras.Input(shape=(input_dim,), dtype=tf.float32)
    x = tf.keras.layers.Dense(8, activation='relu')(i)
    o = tf.keras.layers.Dense(3, activation='sigmoid')(x)
    m = tf.keras.Model(i, o)
    m.compile(optimizer='adam', loss='mse')
    return m

if __name__ == '__main__':
    input_dim = 12  # mean/std for 6 axes
    model = build_model(input_dim)
    # Save Keras then convert
    model.save('driver_safety.keras')
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    with open('driver_safety.tflite', 'wb') as f:
        f.write(tflite_model)
    print('driver_safety.tflite written')
