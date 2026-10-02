#!/usr/bin/env python3
"""Offline resource/source contracts. Runtime loading is checked on macOS separately."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parent.parent
locales = ['en', 'zh-Hans', 'zh-Hant']
checks = 0

def check(value, message):
    global checks
    assert value, message
    checks += 1

def read_table(path):
    result = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith('//'):
            continue
        match = re.fullmatch(r'("(?:\\.|[^"\\])*") = ("(?:\\.|[^"\\])*");', line)
        check(match is not None, f'{path}:{number}: malformed .strings entry')
        key, value = map(json.loads, match.groups())
        check(key not in result, f'{path}:{number}: duplicate {key}')
        check(bool(value), f'{path}:{number}: empty {key}')
        result[key] = value
    return result

tables = {locale: read_table(root / 'Sources/vRemote/Resources' / (locale + '.lproj') / 'Localizable.strings') for locale in locales}
keys = set(tables['en'])
check(len(keys) >= 400, 'expected complete production catalog')
for locale, table in tables.items():
    check(set(table) == keys, f'{locale}: catalog key mismatch')
    for key, value in table.items():
        placeholders = sorted(re.findall(r'\{\d+\}', value))
        check(placeholders == sorted(re.findall(r'\{\d+\}', tables['en'][key])), f'{locale}:{key}: placeholder mismatch')
        check(sorted(re.findall(r'%(?:\d+\$)?(?:\.\d+)?[d@f]', value)) == sorted(re.findall(r'%(?:\d+\$)?(?:\.\d+)?[d@f]', tables['en'][key])), f'{locale}:{key}: printf placeholder mismatch')
        check('HTML' not in value and 'JSON' not in value, f'{locale}:{key}: developer-only archive format in customer copy')
        if locale == 'en':
            check(not re.search('[\u3400-\u9fff]', value), f'{key}: Chinese text leaked into English UI')
    info = read_table(root / 'Packaging' / (locale + '.lproj') / 'InfoPlist.strings')
    check(set(info) == {'CFBundleDisplayName', 'CFBundleName', 'NSBluetoothAlwaysUsageDescription', 'NSBluetoothPeripheralUsageDescription', 'NSInputMonitoringUsageDescription'}, f'{locale}: permission metadata parity')

# Scan complete Swift literals, including nested interpolation. Comments, logs,
# legal attribution, device names and immutable protocol diagnostics are separate.
def string_end(source, index):
    index += 1
    while index < len(source):
        if source.startswith('\\(', index):
            index = interpolation_end(source, index + 2)
        elif source[index] == '\\': index += 2
        elif source[index] == '"': return index + 1
        else: index += 1
    raise AssertionError('Unterminated Swift literal')

def interpolation_end(source, index):
    depth = 1
    while index < len(source):
        if source[index] == '"': index = string_end(source, index)
        elif source[index] == '(': depth += 1; index += 1
        elif source[index] == ')':
            depth -= 1; index += 1
            if depth == 0: return index
        else: index += 1
    raise AssertionError('Unterminated Swift interpolation')

def literals(source):
    index = 0
    while index < len(source):
        if source.startswith('//', index):
            end = source.find('\n', index); index = len(source) if end < 0 else end
        elif source.startswith('/*', index):
            end = source.find('*/', index + 2); index = len(source) if end < 0 else end + 2
        elif source[index] == '"':
            start = index; index = string_end(source, index)
            yield start, source[start + 1:index - 1]
        else: index += 1

references = set()
for path in (root / 'Sources/vRemote').rglob('*.swift'):
    source = path.read_text()
    for key in re.findall(r'"((?:console|support|shell|permission|shortcut|appearance|language|backup|diagnostics|storage|common)\.[A-Za-z][\w.]*)"', source):
        references.add(key)
        check(key in keys, f'{path.name}: missing resource key {key}')
    for position, literal in literals(source):
        if not re.search('[\u3400-\u9fff]', literal): continue
        line = source.count('\n', 0, position) + 1
        is_log = literal.startswith('[')
        is_autonym = path.name == 'Localization.swift' and literal in ['简体中文', '繁體中文']
        is_protocol_detail = path.name == 'ATVVProtocol.swift' and literal in ['遥控器不支持 ADPCM 8/16 kHz', '尚未完成 ATVV capabilities 协商']
        is_audio_log_detail = path.name == 'AudioRouteConfiguration.swift' and source.index('var diagnosticDescription: String') < position < source.index('/// A virtual output')
        is_doubao_log_detail = path.name == 'DoubaoAudioStateMonitor.swift' and source.index('var diagnosticDeviceSummary: String') < position < source.index('private static let targetBundleID')
        check(is_log or is_autonym or is_protocol_detail or is_audio_log_detail or is_doubao_log_detail, f'{path.name}:{line}: unlocalized CJK UI literal: {literal}')
    # Direct English SwiftUI prose should also use a key. Symbols, elapsed time,
    # keyboard labels, product/OS names, and interpolated user content are exempt.
    for literal in re.findall(r'\b(?:Text|Button|Label|Toggle|Picker|TextField)\("([^"\\]*)"', source):
        if not re.search('[A-Za-z]', literal): continue
        check(literal in ['Chromecast', 'vRemoteDr 2ch'], f'{path.name}: direct English view text: {literal}')

localization = (root / 'Sources/vRemote/Localization.swift').read_text()
check('case traditionalChinese = "zh-Hant"' in localization, 'Traditional Chinese preference missing')
check('Bundle.module.resourceURL' in localization, 'SwiftPM resource loading missing')
check('Bundle.main.resourceURL' in localization, 'packaged app resource loading missing')
check('NSLocale.currentLocaleDidChangeNotification' in localization, 'system locale changes must refresh')
check('UserDefaults.standard.set' not in localization or 'AppleLanguages' not in re.sub(r'//[^\n]*', '', localization), 'must not write OS language preferences')
view = (root / 'Sources/vRemote/ChromecastConsoleView.swift').read_text()
check('Picker(L10n.tr("language.title")' in view, 'Settings language picker missing')
check('private struct ConsoleMessage' in view and 'message = ""' not in view, 'feedback must survive locale changes')
check('.environment(\\.locale, AppLanguage.selected.locale)' in view, 'SwiftUI locale not updated')
main = (root / 'Sources/vRemote/main.swift').read_text()
for action in ['selectSystemLanguage', 'selectSimplifiedChinese', 'selectTraditionalChinese', 'selectEnglish']:
    body = re.search(r'private func ' + action + r'\(\) \{(.*?)\n    \}', main, re.S).group(1)
    check('AppLanguage.selected =' in body and not re.search(r'restart|stop|reconnect', body, re.I), action + ' must not interrupt a voice session')
check(main.index('if CommandLine.arguments.contains("--localization-self-test")') < main.index('let app = NSApplication.shared'), 'bundle probe must run before app/device startup')
probe = main[main.index('if CommandLine.arguments.contains("--localization-self-test")'):main.index('let app = NSApplication.shared')]
check('Swift.print(' in probe and not re.search(r'(?<![.\w])print\(', probe), 'bundle probe must bypass application logging')
print(f'PASS: {checks} localization contracts; {len(keys)} keys × 3 locales; {len(references)} referenced keys')
print('NOT RUN here: Swift compilation, AppKit rendering, live menu behavior, or hardware acceptance')
