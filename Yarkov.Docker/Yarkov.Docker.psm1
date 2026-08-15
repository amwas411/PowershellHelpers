<#
.SYNOPSIS
Attaches to a docker container.

.DESCRIPTION
The `Enter-DockerContainer` cmdlet starts an interactive session with a single docker container. During the session, the commands that you type run on the container, just as if you were typing directly on the container.
To end the interactive session and disconnect from the container, use the `Ctrl+C` keyboard sequence.#>
function Enter-DockerContainer {
  param (
    [Parameter(Mandatory)][string]
    $CONTAINER
  )
  process {
    docker exec -it ${CONTAINER} /bin/bash
  }
}

Export-ModuleMember -Function Enter-DockerContainer;