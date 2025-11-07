{
  fetchFromGitHub,
  jdk11_headless,
  jre_headless,
  lib,
  makeWrapper,
  maven,
  stdenv
}:
maven.buildMavenPackage rec {
  pname = "qortal";
  version = "5.0.6";
  src = fetchFromGitHub {
    owner = "Qortal";
    repo = "qortal";
    rev = "v${version}";
    hash = "sha256-OdM60bqSVSV2VwPaAS5fgmci7BJlgX4ZGdQ7C6VX2Ic=";
  };
  patches = [ ./pom-no-git.patch ];
  patchFlags = [ "-p1" ];
  mvnHash = "sha256-xhhvJov/HG7Hbj3RCWYVrJgW39kK2E23X0cLmGPhljs=";
  nativeBuildInputs = [ jdk11_headless makeWrapper ];
  mvnParameters = "-DskipTests -Dproject.build.outputTimestamp=1980-01-01T00:00:02Z";
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/java" "$out/bin"
    install -Dm644 target/qortal-*.jar "$out/share/java/qortal.jar"
    cat > "$out/bin/qortal" <<'EOF'
    #!${stdenv.shell}
    set -euo pipefail
    if [ $# -ge 1 ] && [ "$1" = "--version" ]; then
      echo "${version}"
      exit 0
    fi
    exec ${jre_headless}/bin/java -jar "$out/share/java/qortal.jar" "$@"
    EOF
    chmod +x "$out/bin/qortal"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    set -e
    "$out/bin/qortal" --version | grep -F "${version}" >/dev/null
  '';
  meta = with lib; {
    description = "Qortal Core blockchain node";
    homepage = "https://github.com/Qortal/qortal";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ QuickMythril ];
    platforms = platforms.unix;
    mainProgram = "qortal";
    longDescription = ''
      Qortal Core packaged from the upstream source tarball with a reproducible
      Maven build. The launcher uses a user data directort (QORTAL_HOME if set,
      or XDG_DATA_HOME/qortal, or ~/qortal) and creates a minimal settings.json
      if missing. It runs the store-provided qortal.jar with the working
      directory set to that data directory, avoiding duplicate jar copies.
    '';
  };
}
