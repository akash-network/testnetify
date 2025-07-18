GENESIS_DEST_DIR        ?= $(CACHE_DIR)/$(CURRENT_UPGRADE)
GENESIS_DEST            := $(GENESIS_DEST_DIR)/genesis.json
GENESIS_ORIG            ?= $(GENESIS_DEST_DIR)/genesis.orig.json
LZ4_ARCHIVE             ?= $(GENESIS_DEST_DIR)/genesis.json.tar.lz4

GH                      ?= gh

ifneq ($(shell which op),)
	GH := op plugin run -- gh
endif

export GENESIS_ORIG

CHAIN_TOKEN_DENOM        := uakt
CHAIN_VALIDATOR_AMOUNT   := 20000000000000000
CHAIN_VALIDATOR_DELEGATE := 15000000000000000

cache_init      := $(CACHE_DIR)/.init

.PHONY: cache
cache: $(cache_init)

.PHONY: init
init: $(cache_init) $(AKASH) $(test_key)

.PRECIOUS: %/.init
%/.init:
	@echo "creating dir structure..."
	mkdir -p ${@D}
	mkdir -p $(CACHE_BIN)
	mkdir -p $(AKASH_HOME)
	touch $@

$(AKASH): $(cache_init)
	@echo "Installing akash $(BINARY_VERSION) ..."
	mkdir -p $(BIN_DIR)
	curl -sfL https://raw.githubusercontent.com/akash-network/node/master/install.sh | bash -s -- -b $(BIN_DIR) $(BINARY_VERSION)

.PHONY: install
install: $(AKASH)

$(GENESIS_DEST_DIR):
	mkdir -p $(GENESIS_DEST_DIR)

testnetify: $(AKASH) $(GENESIS_DEST_DIR)
	$(AKASH) debug testnetify $(GENESIS_ORIG) $(GENESIS_DEST) -c config-$(CURRENT_UPGRADE).json

$(GENESIS_DEST): $(GENESIS_ORIG)
	$(AKASH) debug testnetify $(GENESIS_ORIG) $(GENESIS_DEST) -c config-$(CURRENT_UPGRADE).json

$(LZ4_ARCHIVE): $(GENESIS_DEST)
	(cd $(GENESIS_DEST_DIR); $(TAR) cvf - genesis.json | lz4 -f - $(LZ4_ARCHIVE))

$(TESTNETIFY_CONFIG): $(GENESIS_BINARY) $(GOMPLATE) $(GENESIS_CONFIG_TEMPLATE)
	$(ROOT_DIR)/scripts/testnetify-render-config.sh \
		$(GENESIS_BINARY) \
		$(KEY_NAME) \
		config-$(UPGRADE_TO).tmpl.json \
		$(TESTNETIFY_CONFIG)

$(GENESIS_ORIG): $(AKASH)
	./run.sh

.PHONY: archive
archive: $(LZ4_ARCHIVE)

.PHONY: clean
clean:
	rm -rf $(CACHE_DIR)

.PHONY: run
run: $(AKASH) $(GENESIS_DEST_DIR) $(GENESIS_ORIG) archive

.PHONY: lz4
lz4:
	@echo "$(LZ4_ARCHIVE)"

.PHONY: release
release:
	$(GH) release upload $(CURRENT_UPGRADE) $(LZ4_ARCHIVE) --clobber
