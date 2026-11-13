"""Generate the checked-in Xcode project using only Python's standard library.

Run after adding/removing Swift files. No third-party project generator is needed.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
VERSION = json.loads((ROOT / 'version.json').read_text(encoding='utf-8'))

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def quote(value):
    return json.dumps(str(value), ensure_ascii=False)

objects = []
def obj(name, body):
    objects.append(f'\t\t{ident(name)} = {{ {body} }};')
    return ident(name)

def config(name, settings):
    return obj(name, 'isa = XCBuildConfiguration; buildSettings = { ' + ' '.join(f'{k} = {v};' for k, v in settings.items()) + f' }}; name = {name.split(":")[-1]};')

def config_list(key, extra):
    entries = []
    for mode in ['Debug', 'Release']:
        settings = {
            'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
            'SWIFT_VERSION': '6.0', 'IPHONEOS_DEPLOYMENT_TARGET': '18.0',
            'SWIFT_STRICT_CONCURRENCY': 'complete', 'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"' if mode == 'Debug' else '"-O"',
            'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else '"dwarf-with-dsym"',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '"DEBUG $(inherited)"' if mode == 'Debug' else '"$(inherited)"',
            'ENABLE_TESTABILITY': 'YES' if mode == 'Debug' else 'NO',
            'ONLY_ACTIVE_ARCH': 'YES' if mode == 'Debug' else 'NO',
        }
        settings.update(extra)
        entries.append(config(f'{key}:{mode}', settings))
    return obj(f'{key}:configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(entries)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

def files(folder, resource=False):
    refs, builds = [], []
    paths = list((ROOT / folder).glob('*.swift'))
    if resource:
        paths += [ROOT / 'App/Resources/Assets.xcassets', ROOT / 'App/Resources/PrivacyInfo.xcprivacy']
    for path in sorted(paths):
        rel = path.relative_to(ROOT).as_posix()
        kind = 'folder.assetcatalog' if path.suffix == '.xcassets' else 'text.xml' if path.suffix == '.xcprivacy' else 'sourcecode.swift'
        ref = obj('file:' + rel, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(rel)}; sourceTree = SOURCE_ROOT;')
        build = obj('build:' + rel, f'isa = PBXBuildFile; fileRef = {ref};')
        refs.append(ref)
        builds.append((path.suffix, build))
    return refs, builds

app_refs, app_files = files('App', True)
test_refs, test_files = files('UITests')
unit_refs, unit_files = files('AppTests')
app_product = obj('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Journal.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = JournalUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
unit_product = obj('unit-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = JournalAppTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
core = obj('core', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = JournalCore;')
core_build = obj('core-build', f'isa = PBXBuildFile; productRef = {core};')

def phase(name, isa, builds):
    return obj(name, f'isa = {isa}; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')

app_phases = [
    phase('app-sources', 'PBXSourcesBuildPhase', [b for ext, b in app_files if ext == '.swift']),
    phase('app-frameworks', 'PBXFrameworksBuildPhase', [core_build]),
    phase('app-resources', 'PBXResourcesBuildPhase', [b for ext, b in app_files if ext != '.swift']),
]
test_phases = [phase('test-sources', 'PBXSourcesBuildPhase', [b for _, b in test_files]), phase('test-frameworks', 'PBXFrameworksBuildPhase', []), phase('test-resources', 'PBXResourcesBuildPhase', [])]
unit_phases = [phase('unit-sources', 'PBXSourcesBuildPhase', [b for _, b in unit_files]), phase('unit-frameworks', 'PBXFrameworksBuildPhase', []), phase('unit-resources', 'PBXResourcesBuildPhase', [])]

app_configs = config_list('app', {
    'PRODUCT_NAME': '"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER': 'eugggeneee.journal.app',
    'GENERATE_INFOPLIST_FILE': 'YES', 'INFOPLIST_KEY_CFBundleDisplayName': 'Journal',
    'INFOPLIST_KEY_LSApplicationCategoryType': '"public.app-category.education"',
    'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations': '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption': 'NO',
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
    'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': '"iphoneos iphonesimulator"',
    'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD': 'NO',
    'MARKETING_VERSION': quote(VERSION['marketing']), 'CURRENT_PROJECT_VERSION': str(VERSION['build']),
    'CODE_SIGN_STYLE': 'Automatic', 'LD_RUNPATH_SEARCH_PATHS': '"$(inherited) @executable_path/Frameworks"',
})
test_configs = config_list('test', {
    'PRODUCT_NAME': '"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER': 'eugggeneee.journal.uitests',
    'GENERATE_INFOPLIST_FILE': 'YES', 'TARGETED_DEVICE_FAMILY': '1', 'TEST_TARGET_NAME': 'Journal',
    'SUPPORTED_PLATFORMS': '"iphoneos iphonesimulator"',
})
unit_configs = config_list('unit', {
    'PRODUCT_NAME': '"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER': 'eugggeneee.journal.apptests',
    'GENERATE_INFOPLIST_FILE': 'YES', 'TARGETED_DEVICE_FAMILY': '1',
    'TEST_HOST': '"$(BUILT_PRODUCTS_DIR)/Journal.app/Journal"', 'BUNDLE_LOADER': '"$(TEST_HOST)"',
    'SUPPORTED_PLATFORMS': '"iphoneos iphonesimulator"',
})
project_configs = config_list('project', {})
proxy = obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("app")}; remoteInfo = Journal;')
dependency = obj('dependency', f'isa = PBXTargetDependency; target = {ident("app")}; targetProxy = {proxy};')
app = obj('app', f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = ({",".join(app_phases)}); buildRules = (); dependencies = (); name = Journal; packageProductDependencies = ({core}); productName = Journal; productReference = {app_product}; productType = "com.apple.product-type.application";')
tests = obj('tests', f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = ({",".join(test_phases)}); buildRules = (); dependencies = ({dependency}); name = JournalUITests; productName = JournalUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
unit = obj('unit', f'isa = PBXNativeTarget; buildConfigurationList = {unit_configs}; buildPhases = ({",".join(unit_phases)}); buildRules = (); dependencies = ({dependency}); name = JournalAppTests; productName = JournalAppTests; productReference = {unit_product}; productType = "com.apple.product-type.bundle.unit-test";')
products = obj('products', f'isa = PBXGroup; children = ({app_product},{test_product},{unit_product}); name = Products; sourceTree = "<group>";')
app_group = obj('app-group', f'isa = PBXGroup; children = ({",".join(app_refs)}); name = App; sourceTree = "<group>";')
test_group = obj('test-group', f'isa = PBXGroup; children = ({",".join(test_refs)}); name = UITests; sourceTree = "<group>";')
unit_group = obj('unit-group', f'isa = PBXGroup; children = ({",".join(unit_refs)}); name = AppTests; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = ({app_group},{test_group},{unit_group},{products}); sourceTree = "<group>";')
obj('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2600; TargetAttributes = {{ {tests} = {{ TestTargetID = {app}; }}; {unit} = {{ TestTargetID = {app}; }}; }}; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ru; hasScannedForEncodings = 0; knownRegions = (ru,en,Base); mainGroup = {main}; packageReferences = ({package}); productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({app},{tests},{unit});')
project_dir = ROOT / 'Journal.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {ident("project")};\n}}\n', encoding='utf-8', newline='\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="Journal.app" BlueprintName="Journal" ReferencedContainer="container:Journal.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests}" BuildableName="JournalUITests.xctest" BlueprintName="JournalUITests" ReferencedContainer="container:Journal.xcodeproj"/></TestableReference><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{unit}" BuildableName="JournalAppTests.xctest" BlueprintName="JournalAppTests" ReferencedContainer="container:Journal.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="Journal.app" BlueprintName="Journal" ReferencedContainer="container:Journal.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir = project_dir / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / 'Journal.xcscheme').write_text(scheme + '\n', encoding='utf-8', newline='\n')
print('Generated Journal.xcodeproj')
