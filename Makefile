.PHONY: app run install clean

app:
	@./scripts/bundle.sh

run: app
	@pkill -x Lookhere || true
	open build/Lookhere.app

install: app
	@pkill -x Lookhere || true
	rm -rf /Applications/Lookhere.app
	cp -R build/Lookhere.app /Applications/
	open /Applications/Lookhere.app

clean:
	rm -rf .build build
