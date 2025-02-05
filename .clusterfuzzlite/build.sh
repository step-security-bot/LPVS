PROJECT=lpvs
PROJECT_GROUP_ID=com.lpvs
PROJECT_ARTIFACT_ID=lpvs
MAIN_REPOSITORY=https://github.com/samsung/lpvs
MAVEN_ARGS="-Djavac.src.version=11 -Djavac.target.version=11 -Denforcer.skip=true -DskipTests -Dgpg.skip"

  # Move seed corpus and dictionary.
  # mv $SRC/{*.zip,*.dict} $OUT

  #install
  # ($MVN install $MAVEN_ARGS -Dmaven.repo.local=$OUT/m2)
  (cd $PROJECT && $MVN install $MAVEN_ARGS -Dmaven.repo.local=$OUT/m2)

  # build classpath
  $MVN dependency:build-classpath -DskipTests -Dmdep.outputFile=cp.txt -Dmaven.repo.local=$OUT/m2

  cp -r $SRC/lpvs/target/test-classes/ $OUT/
  cp -r $SRC/lpvs/target/classes/ $OUT/
  RUNTIME_CLASSPATH_ABSOLUTE="$(cat cp.txt):$OUT/test-classes:$OUT/classes"
  RUNTIME_CLASSPATH=$(echo $RUNTIME_CLASSPATH_ABSOLUTE | sed "s|$OUT|\$this_dir|g")

  for fuzzer in $(find $SRC -name '*Fuzzer.java'); do
    fuzzer_basename=$(basename -s .java $fuzzer)

    # Create an execution wrapper for every fuzztarget
    echo "#!/bin/bash
    # LLVMFuzzerTestOneInput comment for fuzzer detection by infrastructure.
    this_dir=\$(dirname \"\$0\")
    if [[ \"\$@\" =~ (^| )-runs=[0-9]+($| ) ]]; then
      mem_settings='-Xmx1900m:-Xss900k'
    else
      mem_settings='-Xmx2048m:-Xss1024k'
    fi
    LD_LIBRARY_PATH=\"$JVM_LD_LIBRARY_PATH\":\$this_dir \
    \$this_dir/jazzer_driver --agent_path=\$this_dir/jazzer_agent_deploy.jar \
    --cp=$RUNTIME_CLASSPATH \
    --target_class=com.lpvs.util.$fuzzer_basename \
    --jvm_args=\"\$mem_settings\" \
    --instrumentation_includes=\"com.**:org.**\" \
    \$@" > $OUT/$fuzzer_basename
      chmod u+x $OUT/$fuzzer_basename
  done
