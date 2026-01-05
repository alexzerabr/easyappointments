// Set build directory to Flutter's expected location
val flutterBuildDir = file("../build")
rootProject.buildDir = flutterBuildDir

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
