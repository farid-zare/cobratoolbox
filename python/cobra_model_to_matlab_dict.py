from cobra.io.dict import model_to_dict
from cobra.util.array import create_stoichiometric_matrix
import numpy as np

def cobra_model_to_matlab_dict(model):
    """
    Convert a COBRApy model into a MATLAB-compatible dictionary.
    Always includes the stoichiometric matrix S.

    Returns
    -------
    dict
        A Python dictionary safe for MATLAB SDK transfer.
    
    Raises
    ------
    ValueError
        If the stoichiometric matrix cannot be generated.
    """
    model_dict = model_to_dict(model, sort=False)

    # Try to get stoichiometric matrix
    try:
        S = create_stoichiometric_matrix(model)
    except Exception as e:
        raise ValueError(
            "Model is not COBRA Toolbox compatible: could not generate S matrix."
        ) from e

    # Detect type and store accordingly
    if isinstance(S, np.ndarray):
        model_dict["S"] = S.tolist()
    else:
        try:
            S = S.tocoo()
            model_dict["S"] = {
                "row": S.row.tolist(),    # 0-based indices
                "col": S.col.tolist(),
                "data": S.data.tolist(),
                "shape": S.shape,
            }
        except Exception as e:
            raise ValueError(
                "Model S matrix is neither numpy.ndarray nor scipy.sparse. "
                "Cannot export to MATLAB-compatible format."
            ) from e

    return model_dict
