'use strict';

const { Contract } = require('fabric-contract-api');
const crypto = require('crypto');

function stableHash(value) {
  return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

class MaterialPassportContract extends Contract {
  async InitLedger(ctx) {
    const seedPassport = {
      lotId: 'LOT-RARE-EARTH-001',
      materialType: 'Rare Earth Magnet Alloy',
      supplier: 'Exam Demo Supplier',
      originCountry: 'Australia',
      currentOwner: 'Mumbai Advanced Manufacturing Plant',
      lifecycleStatus: 'CREATED',
      qualityEvents: [],
      custodyEvents: [],
      esgEvents: [],
      complianceCertificates: ['ISO-9001-DEMO', 'ISO-14001-DEMO'],
      createdAt: new Date().toISOString()
    };
    seedPassport.documentHash = stableHash(seedPassport);
    await ctx.stub.putState(seedPassport.lotId, Buffer.from(JSON.stringify(seedPassport)));
    return JSON.stringify(seedPassport);
  }

  async PassportExists(ctx, lotId) {
    const buffer = await ctx.stub.getState(lotId);
    return buffer && buffer.length > 0;
  }

  async CreateMaterialPassport(ctx, lotId, materialType, supplier, originCountry, owner, certificatesJson) {
    const exists = await this.PassportExists(ctx, lotId);
    if (exists) {
      throw new Error(`Material passport ${lotId} already exists`);
    }
    const certificates = certificatesJson ? JSON.parse(certificatesJson) : [];
    const passport = {
      lotId,
      materialType,
      supplier,
      originCountry,
      currentOwner: owner,
      lifecycleStatus: 'CREATED',
      qualityEvents: [],
      custodyEvents: [{ from: 'SOURCE', to: owner, location: 'Origin', timestamp: new Date().toISOString() }],
      esgEvents: [],
      complianceCertificates: certificates,
      createdAt: new Date().toISOString()
    };
    passport.documentHash = stableHash(passport);
    await ctx.stub.putState(lotId, Buffer.from(JSON.stringify(passport)));
    return JSON.stringify(passport);
  }

  async AddQualityInspection(ctx, lotId, inspector, result, defectProbability, imageHash, modelName) {
    const passport = await this._read(ctx, lotId);
    const qualityEvent = {
      inspector,
      result,
      defectProbability: Number(defectProbability),
      imageHash,
      modelName,
      timestamp: new Date().toISOString()
    };
    passport.qualityEvents.push(qualityEvent);
    passport.lifecycleStatus = result === 'PASS' ? 'QUALITY_APPROVED' : 'QUALITY_HOLD';
    passport.documentHash = stableHash(passport);
    await ctx.stub.putState(lotId, Buffer.from(JSON.stringify(passport)));
    return JSON.stringify(qualityEvent);
  }

  async TransferCustody(ctx, lotId, fromOwner, toOwner, location, transportMode) {
    const passport = await this._read(ctx, lotId);
    if (passport.currentOwner !== fromOwner) {
      throw new Error(`Custody mismatch. Current owner is ${passport.currentOwner}, not ${fromOwner}`);
    }
    const custodyEvent = {
      from: fromOwner,
      to: toOwner,
      location,
      transportMode,
      timestamp: new Date().toISOString()
    };
    passport.currentOwner = toOwner;
    passport.custodyEvents.push(custodyEvent);
    passport.documentHash = stableHash(passport);
    await ctx.stub.putState(lotId, Buffer.from(JSON.stringify(passport)));
    return JSON.stringify(custodyEvent);
  }

  async AddESGEvent(ctx, lotId, stage, co2eKg, energyKwh, waterLitres, wasteKg) {
    const passport = await this._read(ctx, lotId);
    const esgEvent = {
      stage,
      co2eKg: Number(co2eKg),
      energyKwh: Number(energyKwh),
      waterLitres: Number(waterLitres),
      wasteKg: Number(wasteKg),
      timestamp: new Date().toISOString()
    };
    passport.esgEvents.push(esgEvent);
    passport.documentHash = stableHash(passport);
    await ctx.stub.putState(lotId, Buffer.from(JSON.stringify(passport)));
    return JSON.stringify(esgEvent);
  }

  async ValidateCertification(ctx, lotId, requiredCertificate) {
    const passport = await this._read(ctx, lotId);
    const valid = passport.complianceCertificates.includes(requiredCertificate);
    return JSON.stringify({ lotId, requiredCertificate, valid, checkedAt: new Date().toISOString() });
  }

  async ReadPassport(ctx, lotId) {
    const passport = await this._read(ctx, lotId);
    return JSON.stringify(passport);
  }

  async GetPassportHistory(ctx, lotId) {
    const iterator = await ctx.stub.getHistoryForKey(lotId);
    const history = [];
    while (true) {
      const result = await iterator.next();
      if (result.value) {
        history.push({
          txId: result.value.txId,
          timestamp: result.value.timestamp,
          isDelete: result.value.isDelete,
          value: result.value.value.toString('utf8') ? JSON.parse(result.value.value.toString('utf8')) : null
        });
      }
      if (result.done) {
        await iterator.close();
        return JSON.stringify(history);
      }
    }
  }

  async _read(ctx, lotId) {
    const buffer = await ctx.stub.getState(lotId);
    if (!buffer || buffer.length === 0) {
      throw new Error(`Material passport ${lotId} does not exist`);
    }
    return JSON.parse(buffer.toString());
  }
}

module.exports = MaterialPassportContract;
