import numpy as np
import matlab
from cobra.util.array import create_stoichiometric_matrix

def cobra_model_to_matlab_dict(model):
    """
    Convert a COBRApy model into a MATLAB-compatible struct
    matching COBRA Toolbox expectations.

    Fields:
      S, mets, b, csense, rxns, lb, ub, c, osenseStr,
      genes, rules, metFormulas, metNames, grRules,
      rxnGeneMat, rxnNames, subSystems, description, modelID
    """

    def safe_str(x):
        return "" if x is None else str(x)

    def safe_float(x):
        return 0.0 if x is None else float(x)

    # Dimensions
    m = len(model.metabolites)
    n = len(model.reactions)
    g = len(model.genes)

    # Stoichiometric matrix (dense for transfer)
    S = create_stoichiometric_matrix(model)
    if not isinstance(S, np.ndarray):
        S = S.toarray()
    S = np.nan_to_num(S)
    S_matlab = matlab.double(S.tolist())

    # Reaction-gene incidence (binary matrix)
    rxnGeneMat = np.zeros((n, g))
    gene_index = {gene.id: j for j, gene in enumerate(model.genes)}
    for i, r in enumerate(model.reactions):
        for g_obj in r.genes:
            j = gene_index[g_obj.id]
            rxnGeneMat[i, j] = 1
    rxnGeneMat_matlab = matlab.double(rxnGeneMat.tolist())

    # Assemble struct
    model_dict = {
        "S": S_matlab,
        "mets": [safe_str(met.id) for met in model.metabolites],
        "b": matlab.double([0.0] * m, size=(m, 1)),
        "csense": "E" * m,   # all equalities
        "rxns": [safe_str(r.id) for r in model.reactions],
        "lb": matlab.double([safe_float(r.lower_bound) for r in model.reactions], size=(n, 1)),
        "ub": matlab.double([safe_float(r.upper_bound) for r in model.reactions], size=(n, 1)),
        "c": matlab.double([safe_float(r.objective_coefficient) for r in model.reactions], size=(n, 1)),
        "osenseStr": "max" if model.objective_direction == "max" else "min",
        "genes": [safe_str(gene.id) for gene in model.genes],
        "rules": [safe_str(r.gene_reaction_rule) for r in model.reactions],
        "metFormulas": [safe_str(met.formula) for met in model.metabolites],
        "metNames": [safe_str(met.name) for met in model.metabolites],
        "grRules": [safe_str(r.gene_reaction_rule) for r in model.reactions],
        "rxnGeneMat": rxnGeneMat_matlab,
        "rxnNames": [safe_str(r.name) for r in model.reactions],
        "subSystems": [safe_str(r.subsystem) for r in model.reactions],
        "description": safe_str(getattr(model, "description", "imported from COBRApy")),
        "modelID": safe_str(model.id),
    }

    return model_dict
