import com.android.build.gradle.LibraryExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

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

// shared_preferences_android ve benzeri eklentilerin compileSdk eksikliğini giderir
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByType(LibraryExtension::class.java)
        android?.compileSdk = 35
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
