BINARY_VERSION   ?= v0.22.8
CURRENT_UPGRADE  ?= v0.22.0
export GENESIS_ORIG     ?= genesis.json
GENESIS_DEST_DIR ?= $(CACHE_DIR)/$(CURRENT_UPGRADE)
GENESIS_DEST     := $(GENESIS_DEST_DIR)/genesis.json

CHAIN_TOKEN_DENOM        := uakt
CHAIN_VALIDATOR_AMOUNT   := 20000000000000000
CHAIN_VALIDATOR_DELEGATE := 15000000000000000

LZ4_ARCHIVE     := genesis.json.tar.lz4

BIN_DIR         := $(CACHE_BIN)/$(BINARY_VERSION)
export AKASH    := $(BIN_DIR)/akash

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

archive: testnetify
	tar cvf - -C $(GENESIS_DEST_DIR) genesis.json | lz4 -f - $(LZ4_ARCHIVE)
	
.PHONY: clean
clean:
	rm -rf $(CACHE_DIR)

$(TESTNETIFY_CONFIG): $(GENESIS_BINARY) $(GOMPLATE) $(GENESIS_CONFIG_TEMPLATE)
	$(ROOT_DIR)/script/testnetify-render-config.sh \
		$(GENESIS_BINARY) \
		$(KEY_NAME) \
		config-$(UPGRADE_TO).tmpl.json \
		$(TESTNETIFY_CONFIG)


.PHONY: run-node
run-node: $(AKASH)
	./run.sh

.PHONY: run
run: $(AKASH) $(GENESIS_DEST_DIR) run-node archive
