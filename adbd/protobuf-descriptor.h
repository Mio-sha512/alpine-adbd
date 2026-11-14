/* Empty shadow for <google/protobuf/descriptor.h>.
 *
 * vendor/adb/sysdeps.h probes for protobuf headers with __has_include and
 * pulls them in when a build host happens to ship them. Protobuf drags in
 * absl, whose headers collide with adbd sources (a file-local `strings`
 * variable) and whose inline LOG calls leave the link needing absl libs
 * adbd never links. adbd uses no protobufs at all, so satisfying the probe
 * with an empty file keeps the build host-agnostic. Installed under
 * vendor/linux-adbd/include/google/protobuf/. */
