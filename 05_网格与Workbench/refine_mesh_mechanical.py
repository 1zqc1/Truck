import os

mesh = Model.Mesh
mesh.ElementSize = Quantity("25 [mm]")
mesh.GenerateMesh()

ExtAPI.DataModel.Project.Save()

marker_path = r"C:\Users\LENOVO\Documents\Codex\2026-09-09\new-chat\work\mesh_refinement\mechanical_mesh_done.txt"
with open(marker_path, "w") as marker:
    marker.write("25 mm mesh generated and mesh database saved.\n")
