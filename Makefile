# Flux Build System
# Usage: make build | make install | make clean

APP_NAME = Flux
SCHEME = Flux
PROJECT = Flux.xcodeproj
BUILD_DIR = ./build-output
RELEASE_APP = $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app
REPO_PATH = /Users/jcbbge/flux

# Colors for output
BLUE = \033[0;34m
GREEN = \033[0;32m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: all build install clean verify sign

all: build

build:
	@echo "$(BLUE)Building $(APP_NAME)...$(NC)"
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination "platform=macOS" \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		2>&1 | tee $(BUILD_DIR)/build.log | grep -E "(BUILD|SIGNED|error:|warning:)" | tail -20
	@echo "$(GREEN)Build complete$(NC)"
	@$(MAKE) embed-git-commit
	@$(MAKE) sign
	@$(MAKE) verify

embed-git-commit:
	@echo "$(BLUE)Embedding git commit...$(NC)"
	@COMMIT=$$(git rev-parse --short HEAD); \
	PLIST="$(RELEASE_APP)/Contents/Info.plist"; \
	/usr/libexec/PlistBuddy -c "Delete :GitCommit" "$${PLIST}" 2>/dev/null || true; \
	/usr/libexec/PlistBuddy -c "Add :GitCommit string $${COMMIT}" "$${PLIST}"; \
	echo "$(GREEN)Embedded: $${COMMIT}$(NC)"

sign:
	@echo "$(BLUE)Signing app...$(NC)"
	@xattr -cr $(RELEASE_APP) 2>/dev/null || true
	@codesign --force --deep --sign - $(RELEASE_APP) 2>&1 | grep -v "replacing existing signature" || true
	@echo "$(GREEN)Signed$(NC)"

verify:
	@echo "$(BLUE)Verifying...$(NC)"
	@EMBEDDED=$$(defaults read $(RELEASE_APP)/Contents/Info GitCommit 2>/dev/null || echo "none"); \
	REPO=$$(git rev-parse --short HEAD); \
	if [ "$$EMBEDDED" = "$$REPO" ]; then \
		echo "$(GREEN)✓ Commit match: $$EMBEDDED$(NC)"; \
	else \
		echo "$(RED)✗ Mismatch: build=$$EMBEDDED, repo=$$REPO$(NC)"; \
		exit 1; \
	fi; \
	if codesign -v $(RELEASE_APP) 2>&1 | grep -q "valid"; then \
		echo "$(GREEN)✓ Signature valid$(NC)"; \
	else \
		echo "$(RED)✗ Signature invalid$(NC)"; \
	fi

install: build
	@echo "$(BLUE)Installing to /Applications...$(NC)"
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.2
	@rm -rf $(INSTALL_PATH)
	@cp -R $(RELEASE_APP) /Applications/
	@$(MAKE) verify-installed
	@echo "$(GREEN)Installed. Launch with: make run$(NC)"

verify-installed:
	@EMBEDDED=$$(defaults read $(INSTALL_PATH)/Contents/Info GitCommit 2>/dev/null || echo "none"); \
	REPO=$$(git rev-parse --short HEAD); \
	if [ "$$EMBEDDED" = "$$REPO" ]; then \
		echo "$(GREEN)✓ Installed commit matches: $$EMBEDDED$(NC)"; \
	else \
		echo "$(RED)✗ Installed commit mismatch: $$EMBEDDED vs $$REPO$(NC)"; \
	fi

run:
	@open $(INSTALL_PATH)

clean:
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)Cleaned$(NC)"

clean-all: clean
	@rm -rf $(INSTALL_PATH)
	@echo "$(GREEN)Cleaned including /Applications install$(NC)"

# Development workflow: build and run from build dir (no install needed)
dev:
	@$(MAKE) build
	@open $(RELEASE_APP)
