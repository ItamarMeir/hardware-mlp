

"""
Train a minimal 3-class MLP on the Iris data and export its
weights / biases in **16-bit signed Q7.8 fixed-point**.

Files generated
---------------
w_in_hid.bin   : 4 × 4  (input → hidden)   int16 little-endian
b_hid.bin      : 4      (hidden biases)    int16 little-endian
w_hid_out.bin  : 4 × 3  (hidden → output)  int16 little-endian
b_out.bin      : 3      (output biases)    int16 little-endian
"""

from pathlib import Path
import numpy as np
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier

# --------------------------------------------------------------------
# 1) load the full Iris dataset  (3 classes, 4 features, 150 samples)
# --------------------------------------------------------------------
iris      = load_iris()
X_all     = iris.data                       # shape (150, 4)
y_all     = iris.target                     # labels 0,1,2

X_train, X_test, y_train, y_test = train_test_split(
    X_all, y_all, test_size=0.25, random_state=42, stratify=y_all
)

# --------------------------------------------------------------------
# 2) train a tiny MLP: 4-input ➝ 4-hidden (ReLU) ➝ 3-output (softmax)
# --------------------------------------------------------------------
mlp = MLPClassifier(
    hidden_layer_sizes=(4,),          # one hidden layer, 4 neurons
    activation="relu",
    solver="adam",
    learning_rate_init=0.01,
    max_iter=1000,
    random_state=42,
)
mlp.fit(X_train, y_train)

print(f"Test accuracy: {mlp.score(X_test, y_test)*100:.2f}%")

# --------------------------------------------------------------------
# 3) extract weights / biases  (numpy arrays)
# --------------------------------------------------------------------
W_in_hid  = mlp.coefs_[0]      # shape (4 features, 4 hidden)
b_hid     = mlp.intercepts_[0] # shape (4,)
W_hid_out = mlp.coefs_[1]      # shape (4 hidden, 3 out)
b_out     = mlp.intercepts_[1] # shape (3,)

print("W_in_hid:\n",  W_in_hid)
print("b_hid   :",     b_hid)
print("W_hid_out:\n", W_hid_out)
print("b_out   :",     b_out)

# --------------------------------------------------------------------
# 4) helper: float ➝ fixed-point (Q7.8) and binary dump
# --------------------------------------------------------------------
FRAC_BITS = 8                      # Q7.8  → scale = 2**8 = 256
SCALE     = 1 << FRAC_BITS
OUT_DIR   = Path("Weights")              # current folder; change if you like

def to_fixed(array_f: np.ndarray) -> np.ndarray:
    """Quantise float array to int16 Q7.8 (little-endian)."""
    fixed = np.round(array_f * SCALE).astype("<i2")   # Changed to little-endian
    return fixed

def dump_bin(arr_f: np.ndarray, fname: str, reverse: bool = False) -> None:
    out_path = OUT_DIR / fname
    if reverse:
        arr_f = np.flip(arr_f)  # reverse the flat order
    to_fixed(arr_f).tofile(out_path)
    print(f"  wrote {out_path}  ({arr_f.shape}, dtype=int16)")

dump_bin(W_in_hid.flatten(), "w_in_hid.bin")          # keep order for matrices if needed

# Add after the first weight dump
fixed_vals = to_fixed(W_in_hid.flatten())
print(f"First few weight values: {W_in_hid.flatten()[:5]}")
print(f"First few weights as fixed hex: {[hex(int(v)) for v in fixed_vals[:5]]}")


dump_bin(b_hid,                "b_hid.bin")  # reverse bias vector order
dump_bin(W_hid_out.flatten(), "w_hid_out.bin")         # same for weights
dump_bin(b_out,               "b_out.bin")   # reverse bias
# Save the test set
dump_bin(X_test.flatten(), "x_test.bin")
# Save the test labels as int8 (binary not needed for inference)
y_test = y_test.astype(np.int8)
y_test.tofile(OUT_DIR / "y_test.bin")


# --------------------------------------------------------------------
# 5) sanity-print a few predictions
# --------------------------------------------------------------------
for i in range(min(20, len(X_test))):
    x_sample  = X_test[i]
    pred      = mlp.predict([x_sample])[0]
    print(f"sample {i:2d}:  true={y_test[i]}  pred={pred}")

# print accuracy:
print(f"Test accuracy: {mlp.score(X_test, y_test)*100:.2f}%")

# Add after weight dump
with open(OUT_DIR / "w_in_hid.bin", "rb") as f:
    raw_data = f.read(10)  # First 10 bytes
print(f"Raw binary bytes: {[hex(b) for b in raw_data]}")


# Add to Python script
import os
print(f"x_test.bin size: {os.path.getsize(OUT_DIR / 'x_test.bin')} bytes")