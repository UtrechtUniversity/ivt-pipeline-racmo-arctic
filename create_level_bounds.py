#!/usr/bin/env python3
"""
================================================================================
Script: create_level_bounds.py

Purpose:
--------
This script generates a NetCDF file (level_bounds.nc) containing the vertical
pressure levels ('plev') and their corresponding layer bounds ('plev_bounds').
This file provides the essential vertical coordinate metadata required for
accurate vertical integration of atmospheric variables.

When to run:
------------
Run this script once per dataset (or when pressure levels change) before any
processing steps that require vertical integration (e.g., using CDO's vertint).
It prepares the vertical coordinate information so it can be appended to data
files that may lose bounds metadata during intermediate processing.

Why it is important:
--------------------
When merging the seperate vertical layers files back to one file for vertical 
intergration, the resulting 3d file include pressure levels ('plev') but lacks 
explicit layer bounds needed to compute integrals correctly. Without these bounds,
vertical integration tools fall back on uniform weights, leading to inaccurate
results. This script ensures accurate layer thicknesses are defined, enabling
precise vertical integration in subsequent analysis.

Usage:
------
- Customize pressure level values if needed.
- Run once and keep the generated 'level_bounds.nc' for later use in the workflow.
- Append 'level_bounds.nc' to intermediate files as needed before vertical integration.

================================================================================
"""

import numpy as np
from netCDF4 import Dataset

#plev_vals = np.array([100000, 92500, 85000, 75000, 70000, 60000, 50000, 40000, 30000], dtype='float32')
#plev_bounds_vals = np.array([
#    [101325,  96250],
#    [96250,   88750],
#    [88750,   80000],
#    [80000,   72500],
#    [72500,   65000],
#    [65000,   55000],
#    [55000,   45000],
#    [45000,   35000],
#    [35000,   25000],
#], dtype='float32')

plev_vals = np.array([100000, 92500, 85000, 70000, 60000, 50000, 40000, 30000], dtype='float32')
plev_bounds_vals = np.array([
    [101325,  96250],
    [96250,   88750],
    [88750,   72500],
    [72500,   65000],
    [65000,   55000],
    [55000,   45000],
    [45000,   35000],
    [35000,   25000],
], dtype='float32')

with Dataset('level_bounds.nc', 'w', format='NETCDF3_CLASSIC') as nc:
    nc.createDimension('plev', len(plev_vals))
    nc.createDimension('bnds', 2)
    
    plev = nc.createVariable('plev', 'f8', ('plev',))
    plev_bounds = nc.createVariable('plev_bounds', 'f8', ('plev', 'bnds'))
    
    plev[:] = plev_vals
    plev_bounds[:, :] = plev_bounds_vals
    
    # Attributes
    plev.standard_name = 'air_pressure'
    plev.long_name = 'Pressure Level'
    plev.units = 'Pa'
    plev.positive = 'down'
    plev.axis = 'Z'
    plev._CoordinateAxisType = 'Pressure'
    plev.bounds = 'plev_bounds'
    
    nc.history = 'Created with custom python script on YYYY-MM-DD'

