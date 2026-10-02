// Project-level build configuration untuk Flutter 3.24.x + AGP 9.1.0 + Java 17
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file('.gradle')
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}

task clean(type: Delete) {
    delete rootProject.buildDir
}