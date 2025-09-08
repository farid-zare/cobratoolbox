import numpy as np
from cobra.util.array import create_stoichiometric_matrix
import matlab

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
    
    model_dict = {
        "id": str(model.id or ""),
        "name": str(model.name or "unnamed_model"),
        # leave as plain Python lists of strings
        "metabolites": [m.id for m in model.metabolites],
        "reactions":   [r.id for r in model.reactions],
        "genes":       [g.id for g in model.genes],
    }

    # Stoichiometric matrix
    S = create_stoichiometric_matrix(model)
    if isinstance(S, np.ndarray):
        model_dict["S"] = matlab.double(S.tolist())  # proper numeric matrix
    else:
        S = S.tocoo()
        model_dict["S"] = {
            "row": S.row.tolist(),
            "col": S.col.tolist(),
            "data": S.data.tolist(),
            "shape": S.shape,
        }

    return model_dict






    
