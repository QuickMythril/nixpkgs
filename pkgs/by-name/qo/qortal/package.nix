{
  fetchFromGitHub,
  jdk11,
  jdk11_headless,
  jre_headless,
  lib,
  makeWrapper,
  maven,
  stdenv,
  stdenvNoCC,
  xmlstarlet
}:
let
  dollar = "$";
  qortalVersion = "5.0.6";
  jdk = if stdenv.isDarwin then jdk11 else jdk11_headless;
  jre = if stdenv.isDarwin then jdk11 else jre_headless;
  upstreamSrc = fetchFromGitHub {
    owner = "Qortal";
    repo = "qortal";
    rev = "v${qortalVersion}";
    hash = "sha256-OdM60bqSVSV2VwPaAS5fgmci7BJlgX4ZGdQ7C6VX2Ic=";
  };
  patchedSrc = stdenvNoCC.mkDerivation {
    name = "qortal-src-patched-${qortalVersion}";
    src = upstreamSrc;
    nativeBuildInputs = [ xmlstarlet ];
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      cp -r "$src" "$out"
      chmod -R u+w "$out"
      ns="http://maven.apage.org/POM/4.0.0"
      pom="$out/pom.xml"
      xmlstarlet ed -L -N x="$ns" \
        -d "//x:plugin[x:groupId='pl.project13.maven' and x:artifactId='git-commit-id-plugin']/x:executions" \
        "$pom" || true
      xmlstarlet ed -L -N x="$ns" \
        -d "//x:pluginManagement/x:plugins/x:plugin[x:groupId='pl.project13.maven' and x:artifactId='git-commit-id-plugin']/x:executions" \
        "$pom" || true
    '';
  };
in
maven.buildMavenPackage rec {
  pname = "qortal";
  version = qortalVersion;
  src = patchedSrc;
  mvnHash = lib.fakeHash;
  nativeBuildInputs = [ jdk makeWrapper ];
  mvnDepsParameters = "-Dgit.commit.time=19700101000000 -Dgit.commit.id.full=0000000000000000000000000000000000000000 -Dgit.commit.id.abbrev=0000000";
  mvnParameters = "-DskipTests -Dproject.build.outputTimestamp=1980-01-01T00:00:02Z \
    -Dgit.commit.time=19700101000000 \
    -Dgit.commit.id.full=0000000000000000000000000000000000000000 \
    -Dgit.commit.id.abbrev=0000000";
  preBuild = ''
    mkdir -p target/classes
    if [ ! -f target/classes/git.properties ]; then
      cat > target/classes/git.properties <<'EOF'
git.commit.time=19700101000000
git.commit.id.full=0000000000000000000000000000000000000000
git.commit.id.abbrev=0000000
EOF
    fi
  '';
  installPhase = ''
    runHook preInstall
    install -Dm444 target/qortal-*.jar "$out/share/qortal/qortal.jar"
    if [ -f log4j2.properties ]; then
      install -Dm444 log4j2.properties "$out/share/qortal/log4j2.properties"
    else
      printf '%s\n' '# Default log4j2 configuration (can be overridden by user copy)' \
        > "$out/share/qortal/log4j2.properties"
    fi
    mkdir -p "$out/bin"
    cat > "$out/bin/qortal" <<'EOSH'
#!/bin/sh
set -e
if [ -n "$QORTAL_HOME" ]; then
  STATE_DIR="$QORTAL_HOME"
else
  if [ -n "$XDG_DATA_HOME" ]; then
    STATE_DIR="$XDG_DATA_HOME/qortal"
  else
    STATE_DIR="$HOME/qortal"
  fi
fi
mkdir -p "$STATE_DIR"
cd "$STATE_DIR"
if [ ! -f settings.json ]; then
  printf '{}' > settings.json
fi
if [ ! -f log4j2.properties ]; then
  cp -n "@out@/share/qortal/log4j2.properties" ./log4j2.properties || true
fi
if [ $# -ge 1 ] && [ "x$1" = "x--version" ]; then
  echo "qortal @QORTAL_PKG_VERSION@"
  exit 0
fi
exec "@jre@/bin/java" -Dlog4j.configurationFile=./log4j2.properties -jar "@out@/share/qortal/qortal.jar" "$@"
EOSH
    substituteInPlace "$out/bin/qortal" \
      --subst-var-by jre "${jre}" \
      --subst-var-by out "$out" \
      --subst-var-by QORTAL_PKG_VERSION "${version}"
    chmod +x "$out/bin/qortal"
    runHook postInstall
  '';
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/qortal" --version | grep -F "qortal ${version}"
    test -r "$out/share/qortal/qortal.jar"
    runHook postInstallCheck
  '';
  meta = with lib; {
    description = "Qortal Core blockchain node";
    homepage = "https://github.com/Qortal/qortal";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ QuickMythril ];
    platforms = platforms.unix;
    mainProgram = "qortal";
    changelog = "https://github.com/Qortal/qortal/releases/tag/v${version}";
    longDescription = ''
      Qortal Core packaged from the upstream source tarball with a reproducible
      Maven build. The launcher uses a user data directort (QORTAL_HOME if set,
      or XDG_DATA_HOME/qortal, or ~/qortal) and creates a minimal settings.json
      if missing. It runs the store-provided qortal.jar with the working
      directory set to that data directory, avoiding duplicate jar copies.
    '';
  };
}
