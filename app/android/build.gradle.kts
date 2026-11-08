// agora_rtc_engine 6.6.4 defaults its compileSdk to 31, but its
// androidx dependencies require 33+. The plugin reads the root
// project's ext property `compileSdkVersion` (safeExtGet), so set it
// here — do NOT patch the pub cache, `flutter pub get` would wipe it.
extra["compileSdkVersion"] = 36

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
