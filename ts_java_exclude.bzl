# Copyright 2018 Two Sigma Investments, LP

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Create a Java library with some Java targets excluded from the classpath.

The ts_java_exclude_library rule creates a java_library from other instances of
java_library, but alters the Java run-time classpath so some dependencies are
excluded.

The following example creates a java_library named "libraries_without_guava"
with the contents of both library1 and library2, but with the jars for guava 19
and 20 excluded from the Java run-time classpath.  Both versions of guava must
appear in the transitive dependencies of the libraries.

ts_java_exclude_library(
    name = "libraries_without_guava",
    excludes = [
        "//ext/public/google/guava/19/0:jars",
        "//ext/public/google/guava/20/0:jars",
    ],
    deps = [
        ":library1",
        ":library2",
    ],
)

The run-time Java classpath is the only thing affected by the ts_java_library
rule.  Bazel query results are not affected.  Both versions of guava will be
reported as dependencies of libraries_without_guava.

BUGS
====

If a Java library has a transitive dependency on a native C shared library,
Bazel arranges for the directory containing the native library to be included
in the java.library.path system property of any Java binary built from the Java
library.  Any java_library created using ts_java_exclude_library forgets which
of its dependencies are native libraries, so the dependencies will not appear
in the java.library.path system property unless some other library depends on
them.

"""

def _parse_excludes(excludes):
    # Collect the jar file dependencies of the excluded targets.  While doing
    # so, create a map from jar back to the exclude target label that
    # references it.
    runtime_excludes = []
    compile_time_excludes = []
    exclude_label_for_jar = {}
    for exclude in excludes:
        java_info = exclude[JavaInfo]
        for jar in java_info.transitive_runtime_jars.to_list():
            runtime_excludes.append(jar)
            exclude_label_for_jar[jar] = exclude.label
        for jar in java_info.transitive_compile_time_jars.to_list():
            compile_time_excludes.append(jar)
            exclude_label_for_jar[jar] = exclude.label

    return runtime_excludes, compile_time_excludes, exclude_label_for_jar

def _create_providers(jars, transitive_jars, never_link):
    """Convert jars and transitive jars into a list of JavaInfo providers."""
    transitive_providers = [
        JavaInfo(output_jar = jar, compile_jar = jar, neverlink = never_link)
        for jar in transitive_jars
    ]
    return [
        JavaInfo(
            output_jar = jar,
            compile_jar = jar,
            neverlink = never_link,
            deps = transitive_providers,
        )
        for jar in jars
    ]

def _create_exclude_providers(
        providers,
        runtime_excludes,
        compile_time_excludes,
        exclude_label_for_jar):
    # For every provider, create a new provider that lacks the jars listed in
    # runtime_excludes and compile_time_excludes.
    new_providers = []
    used_exclude_labels = {}
    for provider in providers:
        # Filter the transitive runtime jars.  Keep track of which exclude
        # labels we used.
        transitive_runtime_jars = []
        for jar in provider.transitive_runtime_jars.to_list():
            if jar in runtime_excludes:
                used_exclude_labels[exclude_label_for_jar[jar]] = True
            else:
                transitive_runtime_jars.append(jar)

        # Convert the filtered runtime jars into providers.
        runtime_output_providers = _create_providers(
            provider.runtime_output_jars,
            transitive_runtime_jars,
            False,
        )

        # Filter the transitive compile time jars.  Keep track of which exclude
        # labels we used.
        transtive_compile_time_jars = []
        for jar in provider.transitive_compile_time_jars.to_list():
            if jar in compile_time_excludes:
                used_exclude_labels[exclude_label_for_jar[jar]] = True
            else:
                transtive_compile_time_jars.append(jar)

        # Convert the filtered compile time jars into providers.
        compile_providers = _create_providers(
            provider.compile_jars.to_list(),
            transtive_compile_time_jars,
            True,
        )

        new_providers.append(java_common.merge(runtime_output_providers + compile_providers))

    return new_providers, used_exclude_labels

def _ts_java_exclude_library_impl(ctx):
    deps = ctx.attr.deps
    excludes = ctx.attr.excludes

    # FIXME: Need to figure out how to test for exactly java_library and
    # java_import.  Currently, we are allowing any kind of Java target in deps
    # and excludes.
    for dep in deps:
        if JavaInfo not in dep:
            fail("%s is not a java_library target" % dep.label, attr = "deps")
    for exclude in excludes:
        if JavaInfo not in exclude:
            fail("%s is not a java_import target" % exclude.label, attr = "excludes")

    providers = [dep[JavaInfo] for dep in deps]
    runtime_excludes, compile_time_excludes, exclude_label_for_jar = _parse_excludes(excludes)
    exclude_providers, used_exclude_labels = _create_exclude_providers(
        providers,
        runtime_excludes,
        compile_time_excludes,
        exclude_label_for_jar,
    )

    # Verify that we used every exclude label.
    for exclude in excludes:
        if exclude.label not in used_exclude_labels:
            fail("%s is unnecessary" % exclude.label, attr = "excludes")

    runfiles = ctx.runfiles(collect_data = True, collect_default = True)
    default_info = DefaultInfo(runfiles = runfiles)

    return exclude_providers + [default_info]

ts_java_exclude_library = rule(
    attrs = {
        "excludes": attr.label_list(),
        # This attribute is named "deps" so we can use collect_data and
        # collect_default when calling ctx.runfiles.
        "deps": attr.label_list(),
    },
    provides = [
        DefaultInfo,
        JavaInfo,
    ],
    implementation = _ts_java_exclude_library_impl,
)
