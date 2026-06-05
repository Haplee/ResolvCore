@echo off
REM ResolveCore - Lanzador para Windows con politica de ejecucion por defecto.
REM En equipos con ExecutionPolicy = Restricted (estado nativo de Windows) el
REM doble clic sobre el .ps1 falla con "la ejecucion de scripts esta deshabilitada".
REM Este lanzador evade esa restriccion de forma legitima solo para esta sesion,
REM sin cambiar la politica global del sistema.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ResolveCore.ps1" %*
