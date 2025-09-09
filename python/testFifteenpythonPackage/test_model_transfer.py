import testFifteen
import matlab
import cobra
from setup_model import cobra_model_to_matlab_dict

# Initialize the MATLAB engine
my_testFifteen = testFifteen.initialize()

# Load a COBRA model
model = cobra.io.load_model("textbook")

# Convert the COBRA model to a MATLAB-compatible dictionary
model_dict = cobra_model_to_matlab_dict(model)

# Call the MATLAB function with the model dictionary
solution = my_testFifteen.optimizeCbModel(model_dict, nargout=1)
print(solution)