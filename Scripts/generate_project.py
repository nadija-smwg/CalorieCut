#!/usr/bin/env python3
"""Generate the checked-in dependency-free Xcode project deterministically."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def put(key, body):
    identifier = uid(key)
    objects[identifier] = body
    return identifier

def quote(value): return json.dumps(str(value))
def array(values): return '( ' + ', '.join(values) + ', )' if values else '()'
def settings(values): return '{ ' + ' '.join(f'{key} = {quote(value)};' for key,value in values.items()) + ' }'

products=[]; groups=[]; targets=[]; target_ids={}; configs={}
for name in ['CalorieCut','CalorieCutTests','CalorieCutUITests']:
    target_ids[name]=uid('target:'+name)
    paths=sorted((ROOT/name).rglob('*.swift'))
    file_refs=[]; source_builds=[]; resource_builds=[]
    for path in paths:
        relative=str(path.relative_to(ROOT/name))
        ref=put('file:'+name+relative, f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(relative)}; sourceTree = "<group>";}}')
        file_refs.append(ref)
        source_builds.append(put('build:'+name+relative, f'{{isa = PBXBuildFile; fileRef = {ref};}}'))
    if name=='CalorieCut':
        for path,kind in [('Resources/Assets.xcassets','folder.assetcatalog'),('Resources/PrivacyInfo.xcprivacy','text.xml')]:
            ref=put('file:'+path,f'{{isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = "<group>";}}')
            file_refs.append(ref)
            resource_builds.append(put('build:'+path,f'{{isa = PBXBuildFile; fileRef = {ref};}}'))
        ref=put('file:info', '{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Resources/Info.plist; sourceTree = "<group>";}')
        file_refs.append(ref)
    groups.append(put('group:'+name, f'{{isa = PBXGroup; children = {array(file_refs)}; path = {name}; sourceTree = "<group>";}}'))
    product=put('product:'+name, f'{{isa = PBXFileReference; explicitFileType = {"wrapper.application" if name=="CalorieCut" else "wrapper.cfbundle"}; includeInIndex = 0; path = {name}{".app" if name=="CalorieCut" else ".xctest"}; sourceTree = BUILT_PRODUCTS_DIR;}}')
    products.append(product)
    sources=put('sources:'+name, f'{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(source_builds)}; runOnlyForDeploymentPostprocessing = 0;}}')
    resources=put('resources:'+name, f'{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;}}')
    frameworks=put('frameworks:'+name,'{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}')
    config_ids=[]
    for configuration in ['Debug','Release']:
        values={
            'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.example.'+name,
            'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'TARGETED_DEVICE_FAMILY':'1',
            'CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','SDKROOT':'iphoneos',
            'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO',
            'SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_PREVIEWS':'YES',
            'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if configuration=='Debug' else '-O',
            'GENERATE_INFOPLIST_FILE':'NO' if name=='CalorieCut' else 'YES'
        }
        if name=='CalorieCut':
            values.update({'INFOPLIST_FILE':'CalorieCut/Resources/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
                           'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor',
                           'MARKETING_VERSION':'1.0.0','CURRENT_PROJECT_VERSION':'1',
                           'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'})
        else:
            values.update({'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
            if name=='CalorieCutTests':
                values.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/CalorieCut.app/CalorieCut','BUNDLE_LOADER':'$(TEST_HOST)'})
            else: values['TEST_TARGET_NAME']='CalorieCut'
        config_ids.append(put('config:'+name+configuration,f'{{isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {configuration};}}'))
    config_list=put('configlist:'+name, f'{{isa = XCConfigurationList; buildConfigurations = {array(config_ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}')
    deps=[]
    if name!='CalorieCut':
        proxy=put('proxy:'+name,f'{{isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {target_ids["CalorieCut"]}; remoteInfo = CalorieCut;}}')
        deps.append(put('dependency:'+name,f'{{isa = PBXTargetDependency; target = {target_ids["CalorieCut"]}; targetProxy = {proxy};}}'))
    product_type='com.apple.product-type.application' if name=='CalorieCut' else 'com.apple.product-type.bundle.unit-test' if name=='CalorieCutTests' else 'com.apple.product-type.bundle.ui-testing'
    target=put('target:'+name,f'{{isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = {array([sources,frameworks,resources])}; buildRules = (); dependencies = {array(deps)}; name = {name}; productName = {name}; productReference = {product}; productType = {quote(product_type)};}}')
    targets.append(target)
product_group=put('products','{isa = PBXGroup; children = '+array(products)+'; name = Products; sourceTree = "<group>";}')
main_group=put('main','{isa = PBXGroup; children = '+array(groups+[product_group])+'; sourceTree = "<group>";}')
project_configs=[]
for name in ['Debug','Release']:
    values={'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','CLANG_WARN_DOCUMENTATION_COMMENTS':'YES',
            'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17',
            'SWIFT_STRICT_CONCURRENCY':'targeted','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym',
            'ENABLE_TESTABILITY':'YES' if name=='Debug' else 'NO','ONLY_ACTIVE_ARCH':'YES' if name=='Debug' else 'NO',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)' if name=='Debug' else '$(inherited)'}
    project_configs.append(put('projectconfig:'+name,f'{{isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {name};}}'))
project_config_list=put('projectconfiglist','{isa = XCConfigurationList; buildConfigurations = '+array(project_configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
attributes=' '.join(f'{target_ids[name]} = {{CreatedOnToolsVersion = 16.0;'+(f' TestTargetID = {target_ids["CalorieCut"]};' if name!='CalorieCut' else '')+'};' for name in target_ids)
root=put('project',f'{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{{attributes}}};}}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};}}')
text='// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 56;\n objects = {\n'
text+=''.join(f'  {key} = {value};\n' for key,value in sorted(objects.items()))
text+=f' }};\n rootObject = {root};\n}}\n'
(ROOT/'CalorieCut.xcodeproj/project.pbxproj').write_text(text)

def buildable(name):
    extension='.app' if name=='CalorieCut' else '.xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[name]}" BuildableName="{name}{extension}" BlueprintName="{name}" ReferencedContainer="container:CalorieCut.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('CalorieCut')}</BuildActionEntry>
  <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{buildable('CalorieCutTests')}</BuildActionEntry>
  <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{buildable('CalorieCutUITests')}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
  <TestableReference skipped="NO">{buildable('CalorieCutTests')}</TestableReference>
  <TestableReference skipped="NO">{buildable('CalorieCutUITests')}</TestableReference>
 </Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('CalorieCut')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('CalorieCut')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(ROOT/'CalorieCut.xcodeproj/xcshareddata/xcschemes/CalorieCut.xcscheme').write_text(scheme)
info={'CFBundleDevelopmentRegion':'$(DEVELOPMENT_LANGUAGE)','CFBundleDisplayName':'CalorieCut','CFBundleExecutable':'$(EXECUTABLE_NAME)',
      'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)',
      'CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)',
      'LSRequiresIPhoneOS':True,'ITSAppUsesNonExemptEncryption':False,
      'UILaunchScreen':{'UIColorName':'LaunchBackground'},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],
      'UIApplicationSupportsIndirectInputEvents':True,'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{}}}
(ROOT/'CalorieCut/Resources/Info.plist').write_bytes(plistlib.dumps(info))
privacy={'NSPrivacyTracking':False,'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[]}
(ROOT/'CalorieCut/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print(f'Generated project: {len(paths)} UI test files; {len(objects)} project objects, 3 targets.')
