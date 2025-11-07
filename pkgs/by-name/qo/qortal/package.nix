{
  fetchgit,
  jdk11_headless,
  jre_headless,
  lib,
  makeWrapper,
  maven,
  stdenv,
  unzip
}:
maven.buildMavenPackage rec {
  pname = "qortal";
  version = "5.0.6";
  src = fetchgit {
    url = "https://github.com/Qortal/qortal.git";
    rev = "refs/tags/v${version}";
    hash = "sha256-z6QCUaketVJ+EiMJHVdBtvp8FffklEje+Hoy4aBoNek=";
    leaveDotGit = true;
    deepClone= true;
    fetchSubmodules = false;
  };
  mvnHash = "sha256-xhhvJov/HG7Hbj3RCWYVrJgW39kK2E23X0cLmGPhljs=";
  nativeBuildInputs = [
    jdk11_headless
    makeWrapper
  ];
  mvnParameters = "-DskipTests -Dproject.build.outputTimestamp=1980-01-01T00:00:02Z";
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/java $out/share/qortal $out/bin
    jar="$(echo target/qortal-*.jar)"
    install -Dm644 "$jar" "$out/share/java/qortal.jar"
    if [ -f log4j2.properties ]; then
      install -Dm644 log4j2.properties "$out/share/qortal/log4j2.properties"
    fi
    cat > $out/bin/qortal <<'EOF'
    #!@SHELL@
    set -euo pipefail
    if [ $# -ge 1 ] && [ "$1" = "--version" ]; then
      echo "@PKG_VERSION@"
      exit 0
    fi
    set +u
    if [ -n "$QORTAL_HOME" ]; then
      STATE_DIR="$QORTAL_HOME"
    else
      STATE_DIR="$HOME/qortal"
    fi
    set -u
    mkdir -p "STATE_DIR"
    if [ ! -s "$STATE_DIR/settings.json" ]; then
      printf '{}' > "$STATE_DIR/settings.json"
    fi
    cp -f "@OUT@/share/java/qortal.jar" "$STATE_DIR/qortal.jar"
    if [ -f "@OUT@/share/qortal/log4j2.properties" ]; then
      cp -f "@OUT@/share/qortal/log4j2.properties" "$STATE_DIR/log4j2.properties"
    fi
    cd "$STATE_DIR"
    if [ -f "./log4j2.properties" ]; then
      exec @JAVA@ -Dlog4j.configurationFile=./log4j2.properties -jar ./qortal.jar "$@"
    else
      exec @JAVA@ -jar "./qortal.jar" "$@"
    fi
    EOF
    substituteInPlace $out/bin/qortal \
      --subst-var-by JAVA ${jre_headless}/bin/java \
      --subst-var-by OUT $out \
      --subst-var-by PKG_VERSION ${version} \
      --subst-var-by SHELL ${stdenv.shell}
    chmod +x $out/bin/qortal
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    set -euo pipefail
    echo "- Checking wrapper --version..."
    outver="$($out/bin/qortal --version)"
    echo "  reported: $outver"
    if [ "$outver" = "${version}" ]; then
      echo "  OK: wrapper version matches ${version}"
    else
      echo "  FAIL: wrapper reported \"$outver\"; expected \"${version}\""
      exit 1
    fi
    echo "- Checking JAR manifest contains version..."
    if ${unzip}/bin/unzip -p "$out/share/java/qortal.jar" META-INF/MANIFEST.MF | grep -Fq "${version}"; then
      echo "  OK: manifest contains ${version}"
    else
      echo "  FAIL: version not found in manifest; manifest head follows:"
      ${unzip}/bin/unzip -p "$out/share/java/qortal.jar" META-INF/MANIFEST.MF | sed -n '1,120p'
      exit 1
    fi
  '';
  meta = with lib; {
    description = "Qortal Core blockchain node";
    homepage = "https://github.com/Qortal/qortal";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ QuickMythril ];
    platforms = platforms.unix;
    mainProgram = "qortal";
    changelog = "https://github.com/Qortal/qortal/releases/tag/v${version}";
  };
}
