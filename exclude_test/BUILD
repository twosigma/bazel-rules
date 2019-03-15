load("//:ts_java_exclude.bzl", "ts_java_exclude_library")

java_import(
    name = "wanted_dep",
    jars = ["wanted_dep.jar"],
)

java_import(
    name = "unwanted_dep",
    jars = ["unwanted_dep.jar"],
)

java_import(
    name = "wanted_runtime_dep",
    jars = ["wanted_runtime_dep.jar"],
)

java_import(
    name = "unwanted_runtime_dep",
    jars = ["unwanted_runtime_dep.jar"],
)

java_library(
    name = "library_using_wanted",
    srcs = ["LibraryUsingWanted.java"],
    runtime_deps = [":wanted_runtime_dep"],
    deps = [":wanted_dep"],
)

java_library(
    name = "library_using_unwanted",
    srcs = ["LibraryUsingUnwanted.java"],
    runtime_deps = [":unwanted_runtime_dep"],
    deps = [":unwanted_dep"],
)

ts_java_exclude_library(
    name = "library_excluding_unwanted",
    excludes = [
        ":unwanted_dep",
        ":unwanted_runtime_dep",
    ],
    deps = [":library_using_unwanted"],
)

java_binary(
    name = "binary",
    srcs = ["Binary.java"],
    main_class = "exclude_test.Binary",
    deps = [
        ":library_using_unwanted",
        ":library_using_wanted",
    ],
)

java_binary(
    name = "exclude_binary",
    srcs = ["Binary.java"],
    main_class = "exclude_test.Binary",
    deps = [
        ":library_excluding_unwanted",
        ":library_using_wanted",
    ],
)
