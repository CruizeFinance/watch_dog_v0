const { ethers } = require('hardhat')
const assert = require('chai').assert
let [signer, user1] = ''
let assetPoolContract = null

before('AssetPool', async () => {
  ;[signer, user1] = await ethers.getSigners()

  // working on a specifc deployed address ..
  const Exchange = await ethers.getContractFactory('AssetPool', signer)
  assetPoolContract = Exchange.attach(
    '0x1CE212534D0155ff2d1813CC4de13F43AC27DdCa',
  )
})

describe('testing contract functions', function () {
  it('deposit asset', async () => {
    let result = await assetPoolContract
      .connect(signer)
      .depositAsset(
        ethers.utils.parseUnits('0.1', 16),
        '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
      )
    const depositReceipt = await result.wait()
    const crToken = await depositReceipt.events[1].args.value
    assert.notEqual(crToken, 0)
    assert.notEqual(crToken, '')
    assert.notEqual(crToken, null)
    assert.notEqual(crToken, undefined)
    assert.equal(
      ethers.utils.formatUnits(crToken.toString(), 'wei'),
      ethers.utils.parseUnits('0.1', 16),
    )
  })

  it('withdraw asset', async () => {
    try {
      let result = await assetPoolContract
        .connect(signer)
        .withdrawAsset(
          ethers.utils.parseUnits('0.1', 16),
          '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
        )
      const withdrawReceipt = await result.wait()
      const wethToken = await withdrawReceipt.events[1].args.value
      assert.notEqual(wethToken, 0)
      assert.notEqual(wethToken, '')
      assert.notEqual(wethToken, null)
      assert.notEqual(wethToken, undefined)
      assert.equal(
        ethers.utils.formatUnits(wethToken.toString(), 'wei'),
        ethers.utils.parseUnits('0.1', 16),
      )
    } catch (e) {
      console.log(e)
    }
  })
})
