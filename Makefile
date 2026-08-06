.PHONY: build test app dmg clean

build:
	swift build -c release

test:
	swift test

app: build
	bash scripts/build_app.sh

dmg: app
	bash scripts/make_dmg.sh

clean:
	rm -rf .build dist
