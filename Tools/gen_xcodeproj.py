"""Génère RepCounter.xcodeproj/project.pbxproj (identifiants stables).

Usage : python3 Tools/gen_xcodeproj.py — à relancer après l'ajout ou le retrait d'un fichier Swift.
"""
import os

files = ["RepCounterApp.swift","Theme.swift","Audio.swift","ExerciseCarousel.swift","History.swift","HistoryView.swift","Endurance.swift","EnduranceView.swift","Form.swift","Advice.swift","SettingsView.swift","ExerciseIcon.swift","WorkoutView.swift","WorkoutModel.swift","SessionRecorder.swift","Exercise.swift","Placement.swift","PlacementView.swift","PlacementGuide.swift","Onboarding.swift","AutoCounter.swift","GestureTemplate.swift","Phase.swift","PhaseView.swift","Feeling.swift","SensorHub.swift","PoseFeatures.swift","SignalMath.swift","Support.swift"]
def i(p,n): return p + "0"*(23-len(str(n))) + str(n)
fref = {f: i("F",k+1) for k,f in enumerate(files)}
bf = {f: i("B",k+1) for k,f in enumerate(files)}
PRODUCT=i("F",99); ASSETS=i("F",98); ASSETS_BF=i("B",98); THEMES=i("F",97); THEMES_BF=i("B",97); SOUNDS=i("F",96); SOUNDS_BF=i("B",96); XCCONFIG=i("F",95); GCONFIG=i("C",4); GMAIN=i("C",1); GSRC=i("C",2); GPROD=i("C",3)
TARGET=i("D",1); PROJ=i("E",1); PSRC=i("A",1); PFW=i("A",2); PRES=i("A",3); PBUILD=i("A",4)
CPD=i("9",1); CPR=i("9",2); CTD=i("9",3); CTR=i("9",4); LP=i("8",1); LT=i("8",2)
nl="\n"
# Réglages recommandés par Xcode (ceux de son modèle de projet) : sans eux, Xcode propose de
# « mettre à jour les réglages recommandés » et modifie ce fichier, ce qui crée des conflits.
common = '''				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				SDKROOT = iphoneos;
'''
target = '''				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Reps;
				INFOPLIST_KEY_NSCameraUsageDescription = "La caméra sert à suivre tes mouvements pour compter tes répétitions. Rien n'est enregistré.";
				INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES;
				INFOPLIST_KEY_UIFileSharingEnabled = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UIRequiresFullScreen = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 0.1;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
'''
out = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{nl.join(f"		{bf[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref[f]} /* {f} */; }};" for f in files)}
		{ASSETS_BF} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS} /* Assets.xcassets */; }};
		{THEMES_BF} /* Themes.json in Resources */ = {{isa = PBXBuildFile; fileRef = {THEMES} /* Themes.json */; }};
		{SOUNDS_BF} /* Sounds in Resources */ = {{isa = PBXBuildFile; fileRef = {SOUNDS} /* Sounds */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{nl.join(f"		{fref[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};" for f in files)}
		{ASSETS} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{THEMES} /* Themes.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = Themes.json; sourceTree = "<group>"; }};
		{SOUNDS} /* Sounds */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = Sounds; sourceTree = "<group>"; }};
		{XCCONFIG} /* Base.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Base.xcconfig; sourceTree = "<group>"; }};
		{PRODUCT} /* RepCounter.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RepCounter.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{PFW} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{GMAIN} = {{
			isa = PBXGroup;
			children = (
				{GSRC} /* RepCounter */,
				{GCONFIG} /* Config */,
				{GPROD} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{GCONFIG} /* Config */ = {{
			isa = PBXGroup;
			children = (
				{XCCONFIG} /* Base.xcconfig */,
			);
			path = Config;
			sourceTree = "<group>";
		}};
		{GSRC} /* RepCounter */ = {{
			isa = PBXGroup;
			children = (
{nl.join(f"				{fref[f]} /* {f} */," for f in files)}
				{ASSETS} /* Assets.xcassets */,
				{THEMES} /* Themes.json */,
				{SOUNDS} /* Sounds */,
			);
			path = RepCounter;
			sourceTree = "<group>";
		}};
		{GPROD} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{PRODUCT} /* RepCounter.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{TARGET} /* RepCounter */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {LT} /* Build configuration list for PBXNativeTarget "RepCounter" */;
			buildPhases = (
				{PSRC} /* Sources */,
				{PFW} /* Frameworks */,
				{PRES} /* Resources */,
				{PBUILD} /* Numéro de build */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = RepCounter;
			productName = RepCounter;
			productReference = {PRODUCT} /* RepCounter.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJ} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
			}};
			buildConfigurationList = {LP} /* Build configuration list for PBXProject "RepCounter" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = fr;
			hasScannedForEncodings = 0;
			knownRegions = (
				fr,
				en,
				Base,
			);
			mainGroup = {GMAIN};
			productRefGroup = {GPROD} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{TARGET} /* RepCounter */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{PRES} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ASSETS_BF} /* Assets.xcassets in Resources */,
				{THEMES_BF} /* Themes.json in Resources */,
				{SOUNDS_BF} /* Sounds in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
		{PBUILD} /* Numéro de build */ = {{
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)",
			);
			name = "Numéro de build";
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\\"$SRCROOT/Tools/build_number.sh\\"\\n";
			showEnvVarsInLog = 0;
		}};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{PSRC} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{nl.join(f"				{bf[f]} /* {f} in Sources */," for f in files)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{CPD} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{common}				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Debug;
		}};
		{CPR} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{common}				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{CTD} /* Debug */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = {XCCONFIG} /* Base.xcconfig */;
			buildSettings = {{
{target}			}};
			name = Debug;
		}};
		{CTR} /* Release */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = {XCCONFIG} /* Base.xcconfig */;
			buildSettings = {{
{target}			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{LP} /* Build configuration list for PBXProject "RepCounter" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{CPD} /* Debug */,
				{CPR} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{LT} /* Build configuration list for PBXNativeTarget "RepCounter" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{CTD} /* Debug */,
				{CTR} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {PROJ} /* Project object */;
}}
'''
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
open(os.path.join(root, "RepCounter.xcodeproj/project.pbxproj"), "w").write(out)
