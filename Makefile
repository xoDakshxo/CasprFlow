.PHONY: build test run clean

build:
	swift build
	sh Scripts/create_app_bundle.sh debug

test:
	swift run CasprFlowChecks

run: build
	open .build/CasprFlow.app

clean:
	rm -rf .build
