$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & uv venv --python 3.13 --allow-existing .venv
    if ($LASTEXITCODE -ne 0) { throw 'Python environment setup failed.' }
    & uv pip install --python .venv/Scripts/python.exe -r requirements-build.txt
    if ($LASTEXITCODE -ne 0) { throw 'Build dependency installation failed.' }
    & ./.venv/Scripts/python.exe -m unittest discover -s tests -v
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    & ./.venv/Scripts/python.exe -m PyInstaller --noconfirm --clean --onefile --console --noupx --name SBPacker sb_packer.py
    if ($LASTEXITCODE -ne 0) { throw 'EXE build failed.' }
    Write-Output "Built: $PSScriptRoot/dist/SBPacker.exe"
}
finally {
    Pop-Location
}
