"""Génère RepCounter.xcodeproj/project.pbxproj (identifiants stables).

Usage : python3 Tools/gen_xcodeproj.py — à relancer après l'ajout ou le retrait d'un fichier Swift.
"""
import os

files = ["RepCounterApp.swift","Theme.swift","Audio.swift","ExercisePicker.swift","SettingsView.swift","ExerciseIcon.swift","WorkoutView.swift","WorkoutModel.swift","SessionRecorder.swift","Exercise.swift","AutoCounter.swift","SensorHub.swift","PoseFeatures.swift","SignalMath.swift"]
def i(p,n): return p + "0"*(23-len(str(n))) + str(n)
fref = {f: i("F",k+1) for k,f in enumerate(files)}
bf = {f: i("B",k+1) for k,f in enumerate(files)}
PRODUCT=i("F",99); ASSETS=i("F",98); ASSETS_BF=i("B",98); THEMES=i("F",97); THEMES_BF=i("B",97); SOUNDS=i("F",96); SOUNDS_BF=i("B",96); GMAIN=i("C",1); GSRC=i("C",2); GPROD=i("C",3)
TARGET=i("D",1); PROJ=i("E",1); PSRC=i("A",1); PFW=i("A",2); PRES=i("A",3)
CPD=i("9",1); CPR=i("9",2); CTD=i("9",3); CTR=i("9",4); LP=i("8",1); LT=i("8",2)
nl="\n"
common = '''				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				SDKROOT = iphoneos;
'''
target = '''				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
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
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.RepCounter;
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
				{GPROD} /* Products */,
			);
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
			buildSettings = {{
{target}			}};
			name = Debug;
		}};
		{CTR} /* Release */ = {{
			isa = XCBuildConfiguration;
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
