import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension

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

subprojects {
    // This will configure all subprojects (including plugins)
    // to use the Java 8 toolchain for Kotlin compilation.
    project.plugins.withId("org.jetbrains.kotlin.jvm") {
        project.extensions.configure<KotlinJvmProjectExtension> {
            jvmToolchain(8)
        }
    }
}
subprojects {
    project.plugins.withId("com.android.base") {
        val android =
            project.extensions.getByType(com.android.build.gradle.BaseExtension::class.java)
        android.compileSdkVersion(36)
    }
}