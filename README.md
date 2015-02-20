# gosh
------

/* note: go.sh is a work in progress, but we like to think it's still pretty useful. */


A helper utility for configuring paths and using Go.

	$ go.sh -h

	Usage: /usr/local/bin/go.sh [options]
	
	Examples:
	
	  $ go.sh -sp go env
	  $ go.sh -sp go build
	
	Options:
	
	  [ Path flags ]
	  -gp|--gopath /specific/path/    Instruct go.sh to use the specified GOPATH
	  -sp|--shared-gopath             Instruct go.sh to use /root/go as a GOPATH
	  -pp|--project-gopath            Instruct go.sh to create a GOPATH for the specified
	                                  project under /root/.go/TARGET [requires --target]
	  -gr|--goroot /path/to/go        Instruct go.sh to use the go install specified.
	                                  Go officially defaults to /usr/local/go/bin
	
	  [ Build flags ]
	  -b|--build                      Get dependencies and build a --target project [requires --target]
	  -t|--target                     Specify a target for building or setting a GOPATH [requires --build]
	
	  [ Other flags ]
	  -d|--debug                      Instruct go.sh to output debugging information
	  -de|--deactivate                Revert an environment to as it was before sourcing go.sh
	  -h|--help                       Print this helpful information and exit


go.sh can be used to to set environmental variables in a pass-through mode: 

	$ go.sh -sp go env | grep GOPATH
	GOPATH: /root/go already exists in path (not adding).
	GOPATH="/root/go"
	
or can be sourced directly:

	$ source go.sh
	$ echo $GOPATH
	/usr/local/go