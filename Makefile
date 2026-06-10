.PHONY: build run clean install

APP_NAME = PunkType

build:
	swift build -c release

app: build
	./build-app.sh

run: app
	open $(APP_NAME).app

install: app
	-pkill -x $(APP_NAME) 2>/dev/null || true
	sleep 1
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_NAME).app /Applications/
	open /Applications/$(APP_NAME).app
	@echo "✅ Installed to /Applications and relaunched"
	@echo "ℹ️  Signed with a stable identity — TCC permissions survive reinstalls"

clean:
	rm -rf .build
	rm -rf $(APP_NAME).app

dev:
	swift run