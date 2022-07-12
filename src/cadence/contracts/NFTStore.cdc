import NonFungibleToken from 0x631e88ae7f1d7c20

pub contract NFTStore: NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event NFTCreated(id: UInt64)

    // royalties to the creator and to the marketplace
    access(account) var royaltyCut: UFix64

    pub struct Royalties{
        pub let royalty: [Royalty]
        init(royalty: [Royalty]) {
            self.royalty=royalty
        }
    }

    pub enum RoyaltyType: UInt8{
        pub case fixed
        pub case percentage
    }

    pub struct Royalty{
        pub let wallet:Capability<&{FungibleToken.Receiver}> 
        pub let cut: UFix64

        //can be percentage
        pub let type: RoyaltyType

        init(wallet:Capability<&{FungibleToken.Receiver}>, cut: UFix64, type: RoyaltyType ){
            self.wallet=wallet
            self.cut=cut
            self.type=type
        }
    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let ipfsHash: String
        pub var metadata: {String: String}
        access(contract) let royalties: Royalties

        init(ipfsHash: String,  metadata: {String: String}, royalties: Royalties) {
            NFTStore.totalSupply = NFTStore.totalSupply + 1
            self.id = NFTStore.totalSupply
            self.ipfsHash = ipfsHash
            self.metadata = metadata
            self.royalties = royalties

            emit NFTCreated(id: self.id)
        }
    }

    pub resource interface CollectionPublic {
        pub fun borrowEntireNFT(id: UInt64): &NFTStore.NFT
    }

    pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let t <- token as! @NFTStore.NFT
            emit Deposit(id: t.id, to: self.owner?.address)
            self.ownedNFTs[t.id] <-! t
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("The NFT does not exist")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun getMetadata(): Metadata {
            return self.metadata
        }

        pub fun getRoyalties(): Royalties {
            return self.royalties
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowEntireNFT(id: UInt64): &NFTStore.NFT {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return ref as! &NFTStore.NFT
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun mintToken(ipfsHash: String, metadata: {String: String}): @NFTStore.NFT {
        let royalties: [Royalty] = []

        let creatorAccount = getAccount(address)
        royalties.append(Royalty(
            wallet: creatorAccount.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver), 
            cut: Flovatar.getRoyaltyCut(), 
            type: RoyaltyType.percentage
        ))

        royalties.append(Royalty(
            wallet: self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver), 
            cut: Flovatar.getMarketplaceCut(), 
            type: RoyaltyType.percentage
        ))

        return <- create NFT(ipfsHash: ipfsHash, metadata: metadata, royalties: Royalties(royalty: royalties))
    }
    
    init() {
        self.totalSupply = 0

        // Set the default Royalty cut
        self.royaltyCut = 0.05
    }

    // These functions will return the current Royalty cuts for 
    pub fun getRoyaltyCut(): UFix64{
        return self.royaltyCut
    }

    // Only Admins will be able to call the set functions to 
    access(account) fun setRoyaltyCut(value: UFix64){
        self.royaltyCut = value
    }
}