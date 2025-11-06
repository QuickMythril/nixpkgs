{
  lib,
  maven,
  fetchgit,
  jdk11_headless,
  jre_headless,
  makeWrapper,
}:
maven.buildMavenPackage rec {
  pname = "qortal";
  version = "5.0.6";
  src = fetchgit {
    url = "https://github.com/Qortal/qortal.git";
    rev = "refs/tags/v${version}";
    hash = "sha256-z6QCUaketVJ+EiMJHVdBtvp8FffklEje+Hoy4aBoNek=";
    leaveDotGit = true;
    deepClone = true;
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
    mkdir -p $out/share/java $out/bin
    jar="$(echo target/qortal-*.jar)"
    install -Dm644 "$jar" "$out/share/java/qortal.jar"
    makeWrapper ${jre_headless}/bin/java $out/bin/qortal \
      --add-flags "-jar $out/share/java/qortal.jar"
    runHook postInstall
  '';
  meta = with lib; {
    description = "Qortal Core blockchain node";
    homepage = "https://github.com/Qortal/qortal";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ QuickMythril ];
    platforms = platforms.linux;
    mainProgram = "qortal";
    changelog = "https://github.com/Qortal/qortal/releases/tag/v${version}";
  };
}
