"""Build a portable archive from public sources; exclude local account state."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'
ARCHIVE = DIST / 'GPT-Dragon-Pet-Windows-x64.zip'
REQUIRED = [
    'README.md', 'LICENSE', 'THIRD-PARTY.md',
    'DragonHost.cs', 'DragonCodexWatcher.cs', 'Build-Dragon.ps1',
    'Start-Dragon.ps1', 'Start-Dragon.vbs', 'Dragon-Control.ps1',
    'Set-CodexAutoStart.ps1', 'Enable-CodexAutoStart.vbs',
    'Disable-CodexAutoStart.vbs', 'Start-Codex-and-Dragon.vbs',
    'gpt-niang-usage/widget.ps1', 'gpt-niang-usage/widget.xaml',
    'gpt-niang-usage/package.json', 'gpt-niang-usage/LICENSE',
    'gpt-niang-usage/.codex-plugin/plugin.json',
]
DIRECTORIES = [
    'gpt-niang-usage/runtime', 'gpt-niang-usage/assets',
    'gpt-niang-usage/tests', 'tests', 'tools', 'docs',
]
PRIVATE_NAMES = {
    'installation.json', 'status.json', 'settings.json', 'presence.json',
    'runtime.json', 'worker.lock', 'worker-ownership.lock', 'auth.json',
    'gui.lock', 'update-preferences.json',
}


def main():
    files = {ROOT / name for name in REQUIRED}
    for directory in DIRECTORIES:
        files.update(p for p in (ROOT / directory).rglob('*')
                     if p.is_file() and '__pycache__' not in p.parts
                     and p.suffix.lower() not in {'.pyc', '.tmp', '.bak'})
    for name in ['GPTDragonPet.exe', 'GPTDragonCodexWatcher.exe']:
        if (ROOT / name).is_file():
            files.add(ROOT / name)
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(path.relative_to(ROOT))
        if path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f'Nonlocal file: {path.relative_to(ROOT)}')
        if (path.name.lower() in PRIVATE_NAMES or path.name.startswith('.env')
                or path.name.endswith(('-error.txt', '-status.json'))
                or path.suffix.lower() in {'.log', '.flag'}
                or any(part in {'.git', '.test-state', 'node_modules'}
                       for part in path.relative_to(ROOT).parts)):
            raise ValueError(f'Private runtime file in allowlist: {path.relative_to(ROOT)}')
    manifest = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(files)}
    DIST.mkdir(exist_ok=True)
    manifest_text = json.dumps(manifest, indent=2) + '\n'
    (DIST / 'PORTABLE-MANIFEST.json').write_text(manifest_text, encoding='utf-8')
    with zipfile.ZipFile(ARCHIVE, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for name in manifest:
            bundle.write(ROOT / name, 'GPT-Dragon-Pet/' + name)
        bundle.writestr('GPT-Dragon-Pet/PORTABLE-MANIFEST.json', manifest_text)
    with zipfile.ZipFile(ARCHIVE) as bundle:
        if bundle.testzip() is not None:
            raise ValueError('Archive CRC verification failed')
        for name, expected in manifest.items():
            if hashlib.sha256(bundle.read('GPT-Dragon-Pet/' + name)).hexdigest() != expected:
                raise ValueError(f'Archive hash mismatch: {name}')
    digest = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    (DIST / 'SHA256SUMS.txt').write_text(f'{digest}  {ARCHIVE.name}\n', encoding='ascii')
    print(f'PASS: {len(manifest) + 1} allowlisted files; archive CRC and hashes verified; '
          f'{ARCHIVE.stat().st_size} bytes')


if __name__ == '__main__':
    main()
