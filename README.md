# Hardware-MLP: Q7.8 Fixed-Point MLP Inference in SystemVerilog

This project demonstrates a complete end-to-end hardware implementation of a small Multi-Layer Perceptron (MLP) neural network for inference using fixed-point arithmetic in SystemVerilog. It includes all components from the datapath and activation units to full module integration and testing with real-world data (Iris dataset).

## 🚀 Overview

This repository implements a simple 3-class MLP:

* **Input layer:** 4 features
* **Hidden layer:** 4 neurons, with ReLU activation
* **Output layer:** 3-class classifier (Softmax is optional in inference)
* **Data format:** Q7.8 fixed-point (16-bit signed integers with 8 fractional bits)

The entire inference pipeline is implemented in SystemVerilog, including:

* Multiply-accumulate (MAC) units
* Vector ReLU activation
* Layer-wise and full network composition
* Testbenches with file I/O
* Accuracy evaluation against real test data

## 📁 Directory Structure

```
hardware-mlp/
├── DUT/                     # Device Under Test (RTL modules)
│   ├── mac.v                # Single MAC with bias & rounding (Q7.8)
│   ├── layer.v              # Parallel MAC layer
│   ├── relu.v               # ReLU activation unit
│   └── MLP.v                # Full MLP: input -> hidden -> relu -> output
│
├── TB/                      # Testbenches
│   ├── mac_tb.v             # Unit tests for MAC (hand-crafted + random)
│   ├── layer_tb.v           # Layer tests (x_test + assertions)
│   ├── relu_tb.v            # ReLU tests (hand-crafted + random)
│   └── mlp_tb.v             # Full MLP test with Iris test vectors + accuracy check
│
├── Weights/                 # Binary input and model parameter files
│   ├── w_in_hid.bin         # 4x4 weights: input -> hidden
│   ├── b_hid.bin            # 4 biases for hidden layer
│   ├── w_hid_out.bin        # 4x3 weights: hidden -> output
│   ├── b_out.bin            # 3 biases for output layer
│   ├── x_test.bin           # Test input vectors (flattened, Q7.8)
│   └── y_test.bin           # Ground truth labels (int8)
│
├── Iris Dataset/            # Python script to generate weights
│   └── find_weights.py      # Trains MLP + quantizes & exports weights to binary
│
└── README.md                # This file
```

---

## 🧠 What is an MLP?

An MLP (Multi-Layer Perceptron) is a feedforward neural network with:

* One or more hidden layers
* Fully connected neurons
* Non-linear activation functions (e.g., ReLU)

It can approximate complex functions and is widely used in classification, regression, and function approximation tasks.

This design uses:

* **Layer 1:** Linear transformation + bias (4x4 matrix)
* **ReLU:** Sets negative outputs to zero
* **Layer 2:** Linear transformation + bias (4x3 matrix)
* **Argmax:** Determines predicted class

## 📊 Dataset: Iris Classification

The dataset used is the classic [Iris dataset](https://archive.ics.uci.edu/ml/datasets/iris):

* 150 samples
* 4 input features (sepal/petal width & length)
* 3 output classes (Iris-setosa, Iris-versicolor, Iris-virginica)

Training/testing is handled by `find_weights.py`.

---

## ⚙️ How the Weights Are Generated

Run `find_weights.py`:

```bash
python Iris\ Dataset/find_weights.py
```

This script:

1. Trains a 4x4x3 MLPClassifier using `sklearn.neural_network.MLPClassifier`
2. Quantizes all parameters to signed 16-bit Q7.8 fixed-point format
3. Dumps binary files to `Weights/`:

   * `w_in_hid.bin`, `b_hid.bin`: Input to hidden layer
   * `w_hid_out.bin`, `b_out.bin`: Hidden to output layer
   * `x_test.bin`: Test vectors
   * `y_test.bin`: Ground truth labels

---

## ✅ Simulation Instructions (ModelSim)

```bash
# Compile everything
vlog DUT/*.v TB/*.v

# Simulate
vsim -c work.mlp_tb -do "run -all"
```

You should see:

* Test results for each test case
* Per-sample predictions
* Final accuracy summary (usually \~100%)

---

## 📦 Module Descriptions

### mac.v

Multiply-accumulate with:

* Full-precision product (no shift)
* Accumulation
* Bias addition (left-shifted)
* Rounding + right shift (Q7.8)

### layer.v

Parallel instantiation of `mac.v` for a full layer:

* One MAC per output neuron
* Uses `always_comb` to extract columns of weights
* Aggregates `done` signals

### relu.v

Element-wise ReLU:

* Zeroes out negative fixed-point values
* One-cycle latency

### MLP.v

Wires together:

* Input layer → hidden layer (layer.v)
* Hidden → ReLU (relu.v)
* ReLU → output layer (layer.v)
* Generates top-level output

---

## 🧪 Testbenches

Each TB includes hand-crafted and data-driven test cases:

### mac\_tb.v

* Asserts MAC correctness with scalar tests
* Generates 20 random trials

### layer\_tb.v

* Loads binary weights and biases
* Checks output vs expected MAC results

### relu\_tb.v

* Tests sign masking logic
* Random vector checks

### mlp\_tb.v

* Loads all 6 .bin files
* Feeds one sample at a time through full MLP
* Extracts `argmax(mlp_out)` as prediction
* Compares with `y_test.bin`
* Reports final accuracy

---

## 🛠️ Requirements

* Python 3.x (numpy, scikit-learn)
* ModelSim (Intel FPGA Edition 2020.1 or newer)
* (Optional) GTKWave for waveform viewing

---

## 📝 Tips & Notes

* All parameters are signed 16-bit integers in **Q7.8** fixed-point format.
* Data is stored **little-endian** for compatibility with `$fread`.
* Run Python script to regenerate up-to-date weights/test data.
* When debugging, insert `$display` after `$fread` to verify values.
* Keep simulation root as `hardware-mlp/` so `../Weights/` paths resolve.

---

## 🎓 Educational Use

This repository is designed for learning and experimentation with:

* Hardware MLP design
* Fixed-point arithmetic
* Pipelined FSMs
* SystemVerilog testbenches and simulation

Feel free to extend it with quantization-aware training, sigmoid/tanh, softmax, etc.

---

## 📄 License

Open for educational, academic, and non-commercial use.

---

## 📬 Contact

If you found this useful or have suggestions, feel free to contribute or get in touch!

Enjoy building and simulating neural networks in RTL!
# Hardware-MLP: Q7.8 Fixed-Point MLP Inference in SystemVerilog

This project demonstrates a complete end-to-end hardware implementation of a small Multi-Layer Perceptron (MLP) neural network for inference using fixed-point arithmetic in SystemVerilog. It includes all components from the datapath and activation units to full module integration and testing with real-world data (Iris dataset).

## 🚀 Overview

This repository implements a simple 3-class MLP:

* **Input layer:** 4 features
* **Hidden layer:** 4 neurons, with ReLU activation
* **Output layer:** 3-class classifier (Softmax is optional in inference)
* **Data format:** Q7.8 fixed-point (16-bit signed integers with 8 fractional bits)

The entire inference pipeline is implemented in SystemVerilog, including:

* Multiply-accumulate (MAC) units
* Vector ReLU activation
* Layer-wise and full network composition
* Testbenches with file I/O
* Accuracy evaluation against real test data

## 📁 Directory Structure

```
hardware-mlp/
├── DUT/                     # Device Under Test (RTL modules)
│   ├── mac.v                # Single MAC with bias & rounding (Q7.8)
│   ├── layer.v              # Parallel MAC layer
│   ├── relu.v               # ReLU activation unit
│   └── MLP.v                # Full MLP: input -> hidden -> relu -> output
│
├── TB/                      # Testbenches
│   ├── mac_tb.v             # Unit tests for MAC (hand-crafted + random)
│   ├── layer_tb.v           # Layer tests (x_test + assertions)
│   ├── relu_tb.v            # ReLU tests (hand-crafted + random)
│   └── mlp_tb.v             # Full MLP test with Iris test vectors + accuracy check
│
├── Weights/                 # Binary input and model parameter files
│   ├── w_in_hid.bin         # 4x4 weights: input -> hidden
│   ├── b_hid.bin            # 4 biases for hidden layer
│   ├── w_hid_out.bin        # 4x3 weights: hidden -> output
│   ├── b_out.bin            # 3 biases for output layer
│   ├── x_test.bin           # Test input vectors (flattened, Q7.8)
│   └── y_test.bin           # Ground truth labels (int8)
│
├── Iris Dataset/            # Python script to generate weights
│   └── find_weights.py      # Trains MLP + quantizes & exports weights to binary
│
└── README.md                # This file
```

---

## 🧠 What is an MLP?

An MLP (Multi-Layer Perceptron) is a feedforward neural network with:

* One or more hidden layers
* Fully connected neurons
* Non-linear activation functions (e.g., ReLU)

It can approximate complex functions and is widely used in classification, regression, and function approximation tasks.

This design uses:

* **Layer 1:** Linear transformation + bias (4x4 matrix)
* **ReLU:** Sets negative outputs to zero
* **Layer 2:** Linear transformation + bias (4x3 matrix)
* **Argmax:** Determines predicted class

## 📊 Dataset: Iris Classification

The dataset used is the classic [Iris dataset](https://archive.ics.uci.edu/ml/datasets/iris):

* 150 samples
* 4 input features (sepal/petal width & length)
* 3 output classes (Iris-setosa, Iris-versicolor, Iris-virginica)

Training/testing is handled by `find_weights.py`.

---

## ⚙️ How the Weights Are Generated

Run `find_weights.py`:

```bash
python Iris\ Dataset/find_weights.py
```

This script:

1. Trains a 4x4x3 MLPClassifier using `sklearn.neural_network.MLPClassifier`
2. Quantizes all parameters to signed 16-bit Q7.8 fixed-point format
3. Dumps binary files to `Weights/`:

   * `w_in_hid.bin`, `b_hid.bin`: Input to hidden layer
   * `w_hid_out.bin`, `b_out.bin`: Hidden to output layer
   * `x_test.bin`: Test vectors
   * `y_test.bin`: Ground truth labels

---

## ✅ Simulation Instructions (ModelSim)

```bash
# Compile everything
vlog DUT/*.v TB/*.v

# Simulate
vsim -c work.mlp_tb -do "run -all"
```

You should see:

* Test results for each test case
* Per-sample predictions
* Final accuracy summary (usually \~100%)

---

## 📦 Module Descriptions

### mac.v

Multiply-accumulate with:

* Full-precision product (no shift)
* Accumulation
* Bias addition (left-shifted)
* Rounding + right shift (Q7.8)

### layer.v

Parallel instantiation of `mac.v` for a full layer:

* One MAC per output neuron
* Uses `always_comb` to extract columns of weights
* Aggregates `done` signals

### relu.v

Element-wise ReLU:

* Zeroes out negative fixed-point values
* One-cycle latency

### MLP.v

Wires together:

* Input layer → hidden layer (layer.v)
* Hidden → ReLU (relu.v)
* ReLU → output layer (layer.v)
* Generates top-level output

---

## 🧪 Testbenches

Each TB includes hand-crafted and data-driven test cases:

### mac\_tb.v

* Asserts MAC correctness with scalar tests
* Generates 20 random trials

### layer\_tb.v

* Loads binary weights and biases
* Checks output vs expected MAC results

### relu\_tb.v

* Tests sign masking logic
* Random vector checks

### mlp\_tb.v

* Loads all 6 .bin files
* Feeds one sample at a time through full MLP
* Extracts `argmax(mlp_out)` as prediction
* Compares with `y_test.bin`
* Reports final accuracy

---

## 🛠️ Requirements

* Python 3.x (numpy, scikit-learn)
* ModelSim (Intel FPGA Edition 2020.1 or newer)
* (Optional) GTKWave for waveform viewing

---

## 📝 Tips & Notes

* All parameters are signed 16-bit integers in **Q7.8** fixed-point format.
* Data is stored **little-endian** for compatibility with `$fread`.
* Run Python script to regenerate up-to-date weights/test data.
* When debugging, insert `$display` after `$fread` to verify values.
* Keep simulation root as `hardware-mlp/` so `../Weights/` paths resolve.

---

## 🎓 Educational Use

This repository is designed for learning and experimentation with:

* Hardware MLP design
* Fixed-point arithmetic
* Pipelined FSMs
* SystemVerilog testbenches and simulation

Feel free to extend it with quantization-aware training, sigmoid/tanh, softmax, etc.

---

## 📄 License

Open for educational, academic, and non-commercial use.

---

## 📬 Contact

If you found this useful or have suggestions, feel free to contribute or get in touch!

Enjoy building and simulating neural networks in RTL!
