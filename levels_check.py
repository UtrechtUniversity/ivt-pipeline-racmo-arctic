from netCDF4 import Dataset
import numpy as np

# Load your file
ds = Dataset('level_bounds.nc')

plev = ds.variables['plev'][:]
plev_bounds = ds.variables['plev_bounds'][:]

# Compare midpoint of bounds with plev
for i in range(len(plev)):
    midpoint = np.mean(plev_bounds[i])
    diff = abs(midpoint - plev[i])
    print(f"plev: {plev[i]:8.1f} | midpoint: {midpoint:8.1f} | diff: {diff:6.1f}")

