// ---- Top-level build file ----

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Add the Google Services plugin for Firebase/Google Sign-In/etc.
        classpath("com.google.gms:google-services:4.3.15")
        // Add other classpaths here as needed
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ------- Custom build dir logic (optional/advanced) -------
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.value(newSubprojectBuildDir)

    // Ensure subprojects are evaluated after ':app'
    evaluationDependsOn(":app")
}

// Clean task for the new build output dir
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
