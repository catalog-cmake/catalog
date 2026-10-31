set(_CL_COMPLETION_BASH [==[
_catalog_prefix() {
  awk -v p="$1" 'BEGIN { p = tolower(p) } index(tolower($0), p) == 1'
}

_catalog() {
  local cur prev cmd i skip=0 w
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  if [ "$prev" = "=" ] && [ "$COMP_CWORD" -ge 2 ]; then
    prev=${COMP_WORDS[COMP_CWORD-2]}
  fi

  cmd=
  for ((i = 1; i < COMP_CWORD; i++)); do
    w=${COMP_WORDS[i]}
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case $w in
      --toolchain|--target|--prefix|--repo|--recipe|--build-type|--define|--shell|-D) skip=1 ;;
      -*) ;;
      *) cmd=$w; break ;;
    esac
  done

  case $prev in
    --toolchain|--prefix|--repo|--recipe)
      COMPREPLY=($(compgen -f -- "$cur")); return ;;
    --build-type)
      COMPREPLY=($(compgen -W "Release Debug RelWithDebInfo MinSizeRel" -- "$cur")); return ;;
    --shell)
      COMPREPLY=($(compgen -W "sh bash zsh fish powershell cmd" -- "$cur")); return ;;
    --target|--define|-D)
      return ;;
  esac

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W "--toolchain --target --prefix --define --repo --recipe --no-default-repo --refresh --static --shared --lib --exe --app --no-prebuilt --source --build-type --force --dry-run --yes --all --interactive --long --names --json --shell --verbose --help --version" -- "$cur"))
    return
  fi

  case $cmd in
    "")
      COMPREPLY=($(compgen -W "install add remove uninstall rm list ls search check outdated update upgrade clean env prefix completion help version" -- "$cur")) ;;
    install|add|check)
      mapfile -t COMPREPLY < <(catalog search "$cur" 2>/dev/null | _catalog_prefix "$cur") ;;
    remove|uninstall|rm|outdated|update|upgrade)
      mapfile -t COMPREPLY < <(catalog list 2>/dev/null | awk 'NR > 1 { print $1 }' | _catalog_prefix "$cur") ;;
    completion)
      COMPREPLY=($(compgen -W "bash zsh fish powershell" -- "$cur")) ;;
  esac
}
complete -F _catalog catalog
]==])

set(_CL_COMPLETION_ZSH [==[
#compdef catalog
_catalog() {
  local state
  local -a cmds pkgs
  cmds=(
    'install:make libraries available'
    'add:make libraries available'
    'remove:remove packages installed by Catalog'
    'uninstall:remove packages installed by Catalog'
    'rm:remove packages installed by Catalog'
    'list:show recorded packages for the target'
    'ls:show recorded packages for the target'
    'search:find recipes by name'
    'check:report package availability'
    'outdated:compare installed versions with the latest'
    'update:update packages installed by Catalog'
    'upgrade:update packages installed by Catalog'
    'clean:delete cached downloads and build trees'
    'env:print shell exports'
    'prefix:print the install prefix'
    'completion:print a shell completion script'
    'help:show help'
    'version:show version'
  )

  _arguments -C \
    '--toolchain=[CMake toolchain file of the target]:file:_files' \
    '--target=[name of the target]:name' \
    '--prefix=[install into DIR]:directory:_files -/' \
    '*-D[extra CMake definition]:definition' \
    '*--repo=[extra recipe repository]:repository:_files' \
    '*--recipe=[single recipe]:NAME=SRC' \
    '--no-default-repo[do not load the official repo]' \
    '--refresh[re-download cached recipes and sources]' \
    '(--shared)--static[require a static build]' \
    '(--static)--shared[require a shared build]' \
    '--lib[the library of a package]' \
    '(--app)--exe[the application of a package]' \
    '(--exe)--app[the application of a package]' \
    '--no-prebuilt[do not use prebuilt binaries]' \
    '--source[forcefully build from source]' \
    '--build-type=[build type for source builds]:type:(Release Debug RelWithDebInfo MinSizeRel)' \
    '(-f --force)'{-f,--force}'[redo packages already in the manifest]' \
    '(-y --yes)'{-y,--yes}'[skip all prompts]' \
    '(-n --dry-run)'{-n,--dry-run}'[show what would happen]' \
    '--all[clean: all targets]' \
    '(-i --interactive)'{-i,--interactive}'[search: pick with fzf]' \
    '--long[search: table with kind, version and description]' \
    '--names[search: only the names]' \
    '--shell=[env: shell to print for]:shell:(sh bash zsh fish powershell cmd)' \
    '--json[list: print the manifest as JSON]' \
    '(-V --verbose)'{-V,--verbose}'[more verbose logging]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '--version[show version]' \
    '1: :->cmd' \
    '*:: :->args'

  case $state in
    cmd)
      _describe -t commands command cmds ;;
    args)
      case $words[1] in
        install|add|check)
          pkgs=(${(f)"$(catalog search ${PREFIX} 2>/dev/null)"})
          compadd -M 'm:{a-zA-Z}={A-Za-z}' -a pkgs ;;
        remove|uninstall|rm|outdated|update|upgrade)
          pkgs=(${(f)"$(catalog list 2>/dev/null | awk 'NR > 1 { print $1 }')"})
          compadd -M 'm:{a-zA-Z}={A-Za-z}' -a pkgs ;;
        completion)
          compadd bash zsh fish powershell ;;
      esac ;;
  esac
}

if [ "$funcstack[1]" = "_catalog" ]; then
  _catalog "$@"
else
  compdef _catalog catalog
fi
]==])

set(_CL_COMPLETION_FISH [==[
complete -c catalog -f

set -l __catalog_cmds install add remove uninstall rm list ls search check outdated update upgrade clean env prefix completion help version

complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a install -d 'Make libraries available'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a add -d 'Make libraries available'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a remove -d 'Remove packages installed by Catalog'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a uninstall -d 'Remove packages installed by Catalog'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a rm -d 'Remove packages installed by Catalog'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a list -d 'Show recorded packages for the target'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a ls -d 'Show recorded packages for the target'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a search -d 'Find recipes by name'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a check -d 'Report package availability'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a outdated -d 'Compare installed versions with the latest'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a update -d 'Update packages installed by Catalog'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a upgrade -d 'Update packages installed by Catalog'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a clean -d 'Delete cached downloads and build trees'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a env -d 'Print shell exports'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a prefix -d 'Print the install prefix'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a completion -d 'Print a shell completion script'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a help -d 'Show help'
complete -c catalog -n "not __fish_seen_subcommand_from $__catalog_cmds" -a version -d 'Show version'

complete -c catalog -n '__fish_seen_subcommand_from install add check' -a '(catalog search (commandline -ct) 2>/dev/null)'
complete -c catalog -n '__fish_seen_subcommand_from remove uninstall rm outdated update upgrade' -a '(catalog list 2>/dev/null | string match -rv "^NAME" | string replace -r "\s.*" "")'
complete -c catalog -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish powershell'

complete -c catalog -l toolchain -r -F -d 'CMake toolchain file of the target'
complete -c catalog -l target -x -d 'Name of the target'
complete -c catalog -l prefix -r -a '(__fish_complete_directories)' -d 'Install into DIR'
complete -c catalog -s D -l define -x -d 'Extra CMake definition'
complete -c catalog -l repo -r -F -d 'Extra recipe repository'
complete -c catalog -l recipe -x -d 'Single recipe (NAME=SRC)'
complete -c catalog -l no-default-repo -d 'Do not load the official repo'
complete -c catalog -l refresh -d 'Re-download cached recipes and sources'
complete -c catalog -l static -d 'Require a static build'
complete -c catalog -l shared -d 'Require a shared build'
complete -c catalog -l lib -d 'The library of a package'
complete -c catalog -l exe -d 'The application of a package'
complete -c catalog -l app -d 'The application of a package'
complete -c catalog -l no-prebuilt -d 'Do not use prebuilt binaries'
complete -c catalog -l source -d 'Forcefully build from source'
complete -c catalog -l build-type -x -a 'Release Debug RelWithDebInfo MinSizeRel' -d 'Build type for source builds'
complete -c catalog -s f -l force -d 'Redo packages already in the manifest'
complete -c catalog -s y -l yes -d 'Skip all prompts'
complete -c catalog -s n -l dry-run -d 'Show what would happen'
complete -c catalog -l all -d 'clean: all targets'
complete -c catalog -s i -l interactive -d 'search: pick with fzf'
complete -c catalog -l long -d 'search: table with kind, version and description'
complete -c catalog -l names -d 'search: only the names'
complete -c catalog -l shell -x -a 'sh bash zsh fish powershell cmd' -d 'env: shell to print for'
complete -c catalog -l json -d 'list: print the manifest as JSON'
complete -c catalog -s V -l verbose -d 'More verbose logging'
complete -c catalog -s h -l help -d 'Show help'
complete -c catalog -l version -d 'Show version'
]==])

set(_CL_COMPLETION_POWERSHELL [==[
Register-ArgumentCompleter -Native -CommandName catalog -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)

  $commands = 'install', 'add', 'remove', 'uninstall', 'rm', 'list', 'ls', 'search', 'check', 'outdated', 'update', 'upgrade', 'clean', 'env', 'prefix', 'completion', 'help', 'version'
  $options = '--toolchain', '--target', '--prefix', '--define', '--repo', '--recipe', '--no-default-repo', '--refresh', '--static', '--shared', '--lib', '--exe', '--app', '--no-prebuilt', '--source', '--build-type', '--force', '--dry-run', '--yes', '--all', '--interactive', '--long', '--names', '--json', '--shell', '--verbose', '--help', '--version'
  $valueOptions = '--toolchain', '--target', '--prefix', '--repo', '--recipe', '--build-type', '--define', '--shell', '-D'

  function Complete($items) {
    $items | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
  }

  $words = @($commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
  if ($words.Count -gt 0 -and $wordToComplete -ne '' -and $words[-1] -eq $wordToComplete) {
    if ($words.Count -eq 1) { $words = @() } else { $words = $words[0..($words.Count - 2)] }
  }
  $previous = if ($words.Count -gt 0) { $words[-1] } else { '' }

  $command = $null
  $skip = $false
  foreach ($word in $words) {
    if ($skip) { $skip = $false; continue }
    if ($valueOptions -contains $word) { $skip = $true; continue }
    if ($word.StartsWith('-')) { continue }
    $command = $word
    break
  }

  if ($previous -eq '--build-type') { return Complete @('Release', 'Debug', 'RelWithDebInfo', 'MinSizeRel') }
  if ($previous -eq '--shell') { return Complete @('sh', 'bash', 'zsh', 'fish', 'powershell', 'cmd') }
  if ($valueOptions -contains $previous) { return }

  if ($wordToComplete.StartsWith('-')) { return Complete $options }
  if (-not $command) { return Complete $commands }

  switch ($command) {
    { $_ -in 'install', 'add', 'check' } {
      Complete @(& catalog search $wordToComplete --names 2>$null)
    }
    { $_ -in 'remove', 'uninstall', 'rm', 'outdated', 'update', 'upgrade' } {
      Complete @(& catalog list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] })
    }
    'completion' { Complete @('bash', 'zsh', 'fish', 'powershell') }
  }
}
]==])

function(_cl_cmd_completion)
  list(LENGTH CL_PKGS N)
  if(N EQUAL 0)
    _cl_die("completion: give a shell (bash, zsh, fish or powershell)")
  endif()
  list(GET CL_PKGS 0 SHELL)
  if(SHELL STREQUAL "pwsh")
    set(SHELL powershell)
  endif()
  string(TOUPPER "${SHELL}" UPPER)
  if(NOT SHELL MATCHES "^(bash|zsh|fish|powershell)$")
    _cl_die("completion: unsupported shell '${SHELL}' (bash, zsh, fish or powershell)")
  endif()
  _cl_say("${_CL_COMPLETION_${UPPER}}")
endfunction()
