codeunit 4022 "GP Vendor Migrator"
{
    TableNo = "GP Vendor";

    var
        GlobalDocumentNo: Text[30];
        PostingGroupCodeTxt: Label 'GP', Locked = true;
        VendorBatchNameTxt: Label 'GPVEND', Locked = true;
        SourceCodeTxt: Label 'GENJNL', Locked = true;
        PostingGroupDescriptionTxt: Label 'Migrated from GP', Locked = true;

#pragma warning disable AA0207
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Vendor Data Migration Facade", 'OnMigrateVendor', '', true, true)]
    procedure OnMigrateVendor(var Sender: Codeunit "Vendor Data Migration Facade"; RecordIdToMigrate: RecordId)
    var
        GPVendor: Record "GP Vendor";
    begin
        if RecordIdToMigrate.TableNo() <> Database::"GP Vendor" then
            exit;
        GPVendor.Get(RecordIdToMigrate);
        MigrateVendorDetails(GPVendor, Sender);
        MigrateVendorAddresses(GPVendor);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Vendor Data Migration Facade", 'OnMigrateVendorPostingGroups', '', true, true)]
    procedure OnMigrateVendorPostingGroups(var Sender: Codeunit "Vendor Data Migration Facade"; RecordIdToMigrate: RecordId; ChartOfAccountsMigrated: Boolean)
    var
        HelperFunctions: Codeunit "Helper Functions";
    begin
        if not ChartOfAccountsMigrated then
            exit;

        if RecordIdToMigrate.TableNo() <> Database::"GP Vendor" then
            exit;

        Sender.CreatePostingSetupIfNeeded(
            CopyStr(PostingGroupCodeTxt, 1, 5),
            CopyStr(PostingGroupDescriptionTxt, 1, 20),
            HelperFunctions.GetPostingAccountNumber('PayablesAccount')
        );

        Sender.SetVendorPostingGroup(CopyStr(PostingGroupCodeTxt, 1, 5));
        Sender.ModifyVendor(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Vendor Data Migration Facade", 'OnMigrateVendorTransactions', '', true, true)]
    procedure OnMigrateVendorTransactions(var Sender: Codeunit "Vendor Data Migration Facade"; RecordIdToMigrate: RecordId; ChartOfAccountsMigrated: Boolean)
    var
        GPVendor: Record "GP Vendor";
        GPVendorTransactions: Record "GP Vendor Transactions";
        GPCompanyAdditionalSettings: Record "GP Company Additional Settings";
        DataMigrationFacadeHelper: Codeunit "Data Migration Facade Helper";
        HelperFunctions: Codeunit "Helper Functions";
        PaymentTermsFormula: DateFormula;
    begin
        if not ChartOfAccountsMigrated then
            exit;

        if RecordIdToMigrate.TableNo() <> Database::"GP Vendor" then
            exit;

        if GPCompanyAdditionalSettings.GetMigrateOnlyPayablesMaster() then
            exit;

        GPVendor.Get(RecordIdToMigrate);
        Sender.CreateGeneralJournalBatchIfNeeded(CopyStr(VendorBatchNameTxt, 1, 7), '', '');
        GPVendorTransactions.SetRange(VENDORID, GPVendor.VENDORID);
        GPVendorTransactions.SetRange(TransType, GPVendorTransactions.TransType::Invoice);
        if GPVendorTransactions.FindSet() then
            repeat
                Sender.CreateGeneralJournalLine(
                    CopyStr(VendorBatchNameTxt, 1, 7),
                    CopyStr(GPVendorTransactions.GLDocNo, 1, 20),
                    CopyStr(GPVendor.VENDNAME, 1, 50),
                    GPVendorTransactions.DOCDATE,
                    0D,
                    -GPVendorTransactions.CURTRXAM,
                    -GPVendorTransactions.CURTRXAM,
                    '',
                    HelperFunctions.GetPostingAccountNumber('PayablesAccount')
                );
                Sender.SetGeneralJournalLineDocumentType(GPVendorTransactions.TransType);
                DataMigrationFacadeHelper.CreateSourceCodeIfNeeded(CopyStr(SourceCodeTxt, 1, 10));
                Sender.SetGeneralJournalLineSourceCode(CopyStr(SourceCodeTxt, 1, 10));
                if (CopyStr(GPVendorTransactions.PYMTRMID, 1, 10) <> '') then begin
                    Evaluate(PaymentTermsFormula, '');
                    Sender.CreatePaymentTermsIfNeeded(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10), GPVendorTransactions.PYMTRMID, PaymentTermsFormula);
                end;
                Sender.SetGeneralJournalLinePaymentTerms(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10));
                Sender.SetGeneralJournalLineExternalDocumentNo(CopyStr(GPVendorTransactions.DOCNUMBR, 1, 20) + '-' + CopyStr(GPVendorTransactions.GLDocNo, 1, 14));
            until GPVendorTransactions.Next() = 0;

        GPVendorTransactions.Reset();
        GPVendorTransactions.SetRange(VENDORID, GPVendor.VENDORID);
        GPVendorTransactions.SetRange(TransType, GPVendorTransactions.TransType::Payment);
        if GPVendorTransactions.FindSet() then
            repeat
                Sender.CreateGeneralJournalLine(
                    CopyStr(VendorBatchNameTxt, 1, 7),
                    CopyStr(GPVendorTransactions.GLDocNo, 1, 20),
                    CopyStr(GPVendor.VENDNAME, 1, 50),
                    GPVendorTransactions.DOCDATE,
                    0D,
                    GPVendorTransactions.CURTRXAM,
                    GPVendorTransactions.CURTRXAM,
                    '',
                    HelperFunctions.GetPostingAccountNumber('PayablesAccount')
                );
                Sender.SetGeneralJournalLineDocumentType(GPVendorTransactions.TransType);
                Sender.SetGeneralJournalLineSourceCode(CopyStr(SourceCodeTxt, 1, 10));
                if (CopyStr(GPVendorTransactions.PYMTRMID, 1, 10) <> '') then begin
                    Evaluate(PaymentTermsFormula, '');
                    Sender.CreatePaymentTermsIfNeeded(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10), GPVendorTransactions.PYMTRMID, PaymentTermsFormula);
                end;
                Sender.SetGeneralJournalLinePaymentTerms(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10));
                Sender.SetGeneralJournalLineExternalDocumentNo(CopyStr(GPVendorTransactions.DOCNUMBR, 1, 20) + '-' + CopyStr(GPVendorTransactions.GLDocNo, 1, 14));
            until GPVendorTransactions.Next() = 0;

        GPVendorTransactions.Reset();
        GPVendorTransactions.SetRange(VENDORID, GPVendor.VENDORID);
        GPVendorTransactions.SetRange(TransType, GPVendorTransactions.TransType::"Credit Memo");
        if GPVendorTransactions.FindSet() then
            repeat
                Sender.CreateGeneralJournalLine(
                    CopyStr(VendorBatchNameTxt, 1, 7),
                    CopyStr(GPVendorTransactions.GLDocNo, 1, 20),
                    CopyStr(GPVendor.VENDNAME, 1, 50),
                    GPVendorTransactions.DOCDATE,
                    0D,
                    GPVendorTransactions.CURTRXAM,
                    GPVendorTransactions.CURTRXAM,
                    '',
                    HelperFunctions.GetPostingAccountNumber('PayablesAccount')
                );
                Sender.SetGeneralJournalLineDocumentType(GPVendorTransactions.TransType);
                Sender.SetGeneralJournalLineSourceCode(CopyStr(SourceCodeTxt, 1, 10));
                if (CopyStr(GPVendorTransactions.PYMTRMID, 1, 10) <> '') then begin
                    Evaluate(PaymentTermsFormula, '');
                    Sender.CreatePaymentTermsIfNeeded(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10), GPVendorTransactions.PYMTRMID, PaymentTermsFormula);
                end;
                Sender.SetGeneralJournalLinePaymentTerms(CopyStr(GPVendorTransactions.PYMTRMID, 1, 10));
                Sender.SetGeneralJournalLineExternalDocumentNo(CopyStr(GPVendorTransactions.DOCNUMBR, 1, 20) + '-' + CopyStr(GPVendorTransactions.GLDocNo, 1, 14));
            until GPVendorTransactions.Next() = 0;
    end;
#pragma warning restore AA0207

    local procedure MigrateVendorDetails(GPVendor: Record "GP Vendor"; VendorDataMigrationFacade: Codeunit "Vendor Data Migration Facade")
    var
        CompanyInformation: Record "Company Information";
        HelperFunctions: Codeunit "Helper Functions";
        PaymentTermsFormula: DateFormula;
        VendorName: Text[50];
        ContactName: Text[50];
        Country: Code[10];
    begin
        VendorName := CopyStr(GPVendor.VENDNAME, 1, 50);
        ContactName := CopyStr(GPVendor.VNDCNTCT, 1, 50);
        if not VendorDataMigrationFacade.CreateVendorIfNeeded(CopyStr(GPVendor.VENDORID, 1, 20), VendorName) then
            exit;

        if (CopyStr(GPVendor.COUNTRY, 1, 10) <> '') then begin
            HelperFunctions.CreateCountryIfNeeded(CopyStr(GPVendor.COUNTRY, 1, 10), CopyStr(GPVendor.COUNTRY, 1, 10));
            Country := CopyStr(GPVendor.COUNTRY, 1, 10);
        end else begin
            CompanyInformation.Get();
            Country := CompanyInformation."Country/Region Code";
        end;

        if (CopyStr(GPVendor.ZIPCODE, 1, 20) <> '') and (CopyStr(GPVendor.CITY, 1, 30) <> '') then
            VendorDataMigrationFacade.CreatePostCodeIfNeeded(CopyStr(GPVendor.ZIPCODE, 1, 20),
                CopyStr(GPVendor.CITY, 1, 30), CopyStr(GPVendor.STATE, 1, 20), Country);

        VendorDataMigrationFacade.SetAddress(CopyStr(GPVendor.ADDRESS1, 1, 50),
            CopyStr(GPVendor.ADDRESS2, 1, 50), Country,
            CopyStr(GPVendor.ZIPCODE, 1, 20), CopyStr(GPVendor.CITY, 1, 30));

        VendorDataMigrationFacade.SetPhoneNo(HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendor.PHNUMBR1));
        VendorDataMigrationFacade.SetFaxNo(HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendor.FAXNUMBR));
        VendorDataMigrationFacade.SetContact(ContactName);
        VendorDataMigrationFacade.SetVendorPostingGroup(CopyStr(PostingGroupCodeTxt, 1, 5));
        VendorDataMigrationFacade.SetGenBusPostingGroup(CopyStr(PostingGroupCodeTxt, 1, 5));
        VendorDataMigrationFacade.SetEmail(COPYSTR(GPVendor.INET1, 1, 80));
        VendorDataMigrationFacade.SetHomePage(COPYSTR(GPVendor.INET2, 1, 80));
        VendorDataMigrationFacade.SetVendorPostingGroup(CopyStr(PostingGroupCodeTxt, 1, 5));

        if (CopyStr(GPVendor.SHIPMTHD, 1, 10) <> '') then begin
            VendorDataMigrationFacade.CreateShipmentMethodIfNeeded(CopyStr(GPVendor.SHIPMTHD, 1, 10), '');
            VendorDataMigrationFacade.SetShipmentMethodCode(CopyStr(GPVendor.SHIPMTHD, 1, 10));
        end;

        if (CopyStr(GPVendor.PYMTRMID, 1, 10) <> '') then begin
            EVALUATE(PaymentTermsFormula, '');
            VendorDataMigrationFacade.CreatePaymentTermsIfNeeded(CopyStr(GPVendor.PYMTRMID, 1, 10), GPVendor.PYMTRMID, PaymentTermsFormula);
            VendorDataMigrationFacade.SetPaymentTermsCode(CopyStr(GPVendor.PYMTRMID, 1, 10));
        end;

        VendorDataMigrationFacade.SetName2(CopyStr(GPVendor.VNDCHKNM, 1, 50));

        if (GPVendor.TAXSCHID <> '') then begin
            VendorDataMigrationFacade.CreateTaxAreaIfNeeded(GPVendor.TAXSCHID, '');
            VendorDataMigrationFacade.SetTaxAreaCode(GPVendor.TAXSCHID);
            VendorDataMigrationFacade.SetTaxLiable(true);
        end;

        VendorDataMigrationFacade.ModifyVendor(true);
    end;

    local procedure MigrateVendorAddresses(GPVendor: Record "GP Vendor")
    var
        Vendor: Record Vendor;
        GPPM00200: Record "GP PM00200";
        GPVendorAddress: Record "GP Vendor Address";
        AddressCode: Code[10];
        AssignedPrimaryAddressCode: Code[10];
        AssignedRemitToAddressCode: Code[10];
    begin
        if not Vendor.Get(GPVendor.VENDORID) then
            exit;

        if GPPM00200.Get(GPVendor.VENDORID) then begin
            AssignedPrimaryAddressCode := CopyStr(GPPM00200.VADDCDPR.Trim(), 1, MaxStrLen(AssignedPrimaryAddressCode));
            AssignedRemitToAddressCode := CopyStr(GPPM00200.VADCDTRO.Trim(), 1, MaxStrLen(AssignedRemitToAddressCode));
        end;

        GPVendorAddress.SetRange(VENDORID, Vendor."No.");
        if GPVendorAddress.FindSet() then
            repeat
                AddressCode := CopyStr(GPVendorAddress.ADRSCODE.Trim(), 1, MaxStrLen(AddressCode));

                if AddressCode = AssignedRemitToAddressCode then
                    CreateOrUpdateRemitAddress(Vendor, GPVendorAddress, AddressCode);

                if (AddressCode = AssignedPrimaryAddressCode) or (AddressCode <> AssignedRemitToAddressCode) then
                    CreateOrUpdateOrderAddress(Vendor, GPVendorAddress, AddressCode);

            until GPVendorAddress.Next() = 0;
    end;

    local procedure CreateOrUpdateOrderAddress(Vendor: Record Vendor; GPVendorAddress: Record "GP Vendor Address"; AddressCode: Code[10])
    var
        OrderAddress: Record "Order Address";
        HelperFunctions: Codeunit "Helper Functions";
    begin
        if not OrderAddress.Get(Vendor."No.", AddressCode) then begin
            OrderAddress."Vendor No." := Vendor."No.";
            OrderAddress.Code := AddressCode;
            OrderAddress.Insert();
        end;

        OrderAddress.Name := Vendor.Name;
        OrderAddress.Address := GPVendorAddress.ADDRESS1;
        OrderAddress."Address 2" := CopyStr(GPVendorAddress.ADDRESS2, 1, MaxStrLen(OrderAddress."Address 2"));
        OrderAddress.City := CopyStr(GPVendorAddress.CITY, 1, MaxStrLen(OrderAddress.City));
        OrderAddress.Contact := GPVendorAddress.VNDCNTCT;
        OrderAddress."Phone No." := HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendorAddress.PHNUMBR1);
        OrderAddress."Fax No." := HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendorAddress.FAXNUMBR);
        OrderAddress."Post Code" := GPVendorAddress.ZIPCODE;
        OrderAddress.County := GPVendorAddress.STATE;
        OrderAddress.Modify();
    end;

    local procedure CreateOrUpdateRemitAddress(Vendor: Record Vendor; GPVendorAddress: Record "GP Vendor Address"; AddressCode: Code[10])
    var
        RemitAddress: Record "Remit Address";
        HelperFunctions: Codeunit "Helper Functions";
    begin
        if not RemitAddress.Get(AddressCode, Vendor."No.") then begin
            RemitAddress."Vendor No." := Vendor."No.";
            RemitAddress.Code := AddressCode;
            RemitAddress.Insert();
        end;

        RemitAddress.Name := Vendor.Name;
        RemitAddress.Address := GPVendorAddress.ADDRESS1;
        RemitAddress."Address 2" := CopyStr(GPVendorAddress.ADDRESS2, 1, MaxStrLen(RemitAddress."Address 2"));
        RemitAddress.City := CopyStr(GPVendorAddress.CITY, 1, MaxStrLen(RemitAddress.City));
        RemitAddress.Contact := GPVendorAddress.VNDCNTCT;
        RemitAddress."Phone No." := HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendorAddress.PHNUMBR1);
        RemitAddress."Fax No." := HelperFunctions.CleanGPPhoneOrFaxNumber(GPVendorAddress.FAXNUMBR);
        RemitAddress."Post Code" := GPVendorAddress.ZIPCODE;
        RemitAddress.County := GPVendorAddress.STATE;
        RemitAddress.Modify();
    end;

#if not CLEAN21
    [Obsolete('Method is not supported, it was using files', '21.0')]
    procedure GetAll()
    begin
    end;
#endif

    procedure PopulateStagingTable(JArray: JsonArray)
    begin
        GlobalDocumentNo := 'V00000';
        GetPMTrxFromJson(JArray);
    end;

    local procedure GetVendorsFromJson(JArray: JsonArray)
    var
        GPVendor: Record "GP Vendor";
        HelperFunctions: Codeunit "Helper Functions";
        RecordVariant: Variant;
        ChildJToken: JsonToken;
        EntityId: Text[75];
        i: Integer;
    begin
        i := 0;
        GPVendor.Reset();
        GPVendor.DeleteAll();

        while JArray.Get(i, ChildJToken) do begin
            EntityId := CopyStr(HelperFunctions.GetTextFromJToken(ChildJToken, 'VENDORID'), 1, MAXSTRLEN(GPVendor.VENDORID));
            EntityId := CopyStr(HelperFunctions.TrimBackslash(EntityId), 1, 75);
            EntityId := CopyStr(HelperFunctions.TrimStringQuotes(EntityId), 1, 75);

            if not GPVendor.Get(EntityId) then begin
                GPVendor.Init();
                GPVendor.Validate(GPVendor.VENDORID, EntityId);
                GPVendor.Insert(true);
            end;

            RecordVariant := GPVendor;
            UpdateVendorFromJson(RecordVariant, ChildJToken);
            GPVendor := RecordVariant;
            GPVendor.Modify(true);

            i := i + 1;
        end;
    end;

    local procedure UpdateVendorFromJson(var RecordVariant: Variant; JToken: JsonToken)
    var
        GPVendor: Record "GP Vendor";
        HelperFunctions: Codeunit "Helper Functions";
    begin
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(VENDORID), JToken.AsObject(), 'VENDORID');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(VENDNAME), JToken.AsObject(), 'VENDNAME');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(SEARCHNAME), JToken.AsObject(), 'SEARCHNAME');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(VNDCHKNM), JToken.AsObject(), 'VNDCHKNM');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(ADDRESS1), JToken.AsObject(), 'ADDRESS1');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(ADDRESS2), JToken.AsObject(), 'ADDRESS2');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(CITY), JToken.AsObject(), 'CITY');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(VNDCNTCT), JToken.AsObject(), 'VNDCNTCT');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(PHNUMBR1), JToken.AsObject(), 'PHNUMBR1');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(PYMTRMID), JToken.AsObject(), 'PYMTRMID');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(SHIPMTHD), JToken.AsObject(), 'SHIPMTHD');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(COUNTRY), JToken.AsObject(), 'COUNTRY');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(PYMNTPRI), JToken.AsObject(), 'PYMNTPRI');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(AMOUNT), JToken.AsObject(), 'AMOUNT');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(FAXNUMBR), JToken.AsObject(), 'FAXNUMBR');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(ZIPCODE), JToken.AsObject(), 'ZIPCODE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(STATE), JToken.AsObject(), 'STATE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(INET1), JToken.AsObject(), 'INET1');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(INET2), JToken.AsObject(), 'INET2');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(TAXSCHID), JToken.AsObject(), 'TAXSCHID');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(UPSZONE), JToken.AsObject(), 'UPSZONE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendor.FieldNO(TXIDNMBR), JToken.AsObject(), 'TXIDNMBR');
    end;

    procedure PopulateVendorStagingTable(JArray: JsonArray)
    begin
        GetVendorsFromJson(JArray);
    end;

    local procedure GetPMTrxFromJson(JArray: JsonArray);
    var
        GPVendorTransactions: Record "GP Vendor Transactions";
        HelperFunctions: Codeunit "Helper Functions";
        RecordVariant: Variant;
        ChildJToken: JsonToken;
        EntityId: Text[40];
        i: Integer;
    begin
        i := 0;
        GPVendorTransactions.Reset();
        GPVendorTransactions.DeleteAll();

        while JArray.Get(i, ChildJToken) do begin
            EntityId := CopyStr(HelperFunctions.GetTextFromJToken(ChildJToken, 'Id'), 1, MAXSTRLEN(GPVendorTransactions.Id));
            EntityId := CopyStr(HelperFunctions.TrimStringQuotes(EntityId), 1, 40);

            if not GPVendorTransactions.Get(EntityId) then begin
                GPVendorTransactions.Init();
                GPVendorTransactions.Validate(GPVendorTransactions.Id, EntityId);
                GPVendorTransactions.Insert(true);
            end;

            RecordVariant := GPVendorTransactions;
            GlobalDocumentNo := CopyStr(IncStr(GlobalDocumentNo), 1, 30);
            UpdatePMTrxFromJson(RecordVariant, ChildJToken, GlobalDocumentNo);
            GPVendorTransactions := RecordVariant;
            HelperFunctions.SetVendorTransType(GPVendorTransactions);
            GPVendorTransactions.Modify(true);

            i := i + 1;
        end;
    end;

    local procedure UpdatePMTrxFromJson(var RecordVariant: Variant; JToken: JsonToken; DocumentNo: Text[30])
    var
        GPVendorTransactions: Record "GP Vendor Transactions";
        HelperFunctions: Codeunit "Helper Functions";
    begin
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(VENDORID), JToken.AsObject(), 'VENDORID');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(DOCNUMBR), JToken.AsObject(), 'DOCNUMBR');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(DOCDATE), JToken.AsObject(), 'DOCDATE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(DUEDATE), JToken.AsObject(), 'DUEDATE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(CURTRXAM), JToken.AsObject(), 'CURTRXAM');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(DOCTYPE), JToken.AsObject(), 'DOCTYPE');
        HelperFunctions.UpdateFieldValue(RecordVariant, GPVendorTransactions.FieldNo(PYMTRMID), JToken.AsObject(), 'PYMTRMID');
        HelperFunctions.UpdateFieldWithValue(RecordVariant, GPVendorTransactions.FieldNo(GLDocNo), DocumentNo);
    end;

    procedure MigrateVendorEFTBankAccounts()
    var
        GPSY06000: Record "GP SY06000";
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
        GeneralLedgerSetup: Record "General Ledger Setup";
        HelperFunctions: Codeunit "Helper Functions";
        VendorBankAccountExists: Boolean;
        CurrencyCode: Code[10];
    begin
        GPSY06000.SetRange("INACTIVE", false);
        if not GPSY06000.FindSet() then
            exit;

        repeat
            if Vendor.Get(GPSY06000.CustomerVendor_ID) then begin
                CurrencyCode := CopyStr(GPSY06000.CURNCYID, 1, MaxStrLen(CurrencyCode));
                HelperFunctions.CreateCurrencyIfNeeded(CurrencyCode);
                CreateSwiftCodeIfNeeded(GPSY06000.SWIFTADDR);

                VendorBankAccountExists := VendorBankAccount.Get(Vendor."No.", GPSY06000.EFTBankCode);
                VendorBankAccount.Validate("Vendor No.", Vendor."No.");
                VendorBankAccount.Validate("Code", GPSY06000.EFTBankCode);
                VendorBankAccount.Validate("Name", GPSY06000.BANKNAME);
                VendorBankAccount.Validate("Bank Branch No.", GPSY06000.EFTBankBranchCode);
                VendorBankAccount.Validate("Bank Account No.", CopyStr(GPSY06000.EFTBankAcct, 1, 30));
                VendorBankAccount.Validate("Transit No.", GPSY06000.EFTTransitRoutingNo);
                VendorBankAccount.Validate("IBAN", GPSY06000.IntlBankAcctNum);
                VendorBankAccount.Validate("SWIFT Code", GPSY06000.SWIFTADDR);

                if GeneralLedgerSetup.Get() then
                    if GeneralLedgerSetup."LCY Code" <> CurrencyCode then
                        VendorBankAccount.Validate("Currency Code", CurrencyCode);

                if not VendorBankAccountExists then
                    VendorBankAccount.Insert()
                else
                    VendorBankAccount.Modify();

                SetPreferredBankAccountIfNeeded(GPSY06000, Vendor);
            end;
        until GPSY06000.Next() = 0;
    end;

    local procedure CreateSwiftCodeIfNeeded(SWIFTADDR: Text[11])
    var
        SwiftCode: Record "SWIFT Code";
    begin
        if (SWIFTADDR <> '') and not SwiftCode.Get(SWIFTADDR) then begin
            SwiftCode.Validate("Code", SWIFTADDR);
            SwiftCode.Insert();
        end;
    end;

    local procedure SetPreferredBankAccountIfNeeded(GPSY06000: Record "GP SY06000"; var Vendor: Record Vendor)
    var
        SearchGPSY06000: Record "GP SY06000";
        GPPM00200: Record "GP PM00200";
        ShouldSetAsPrimaryAccount: Boolean;
        AddressCode: Code[10];
        PrimaryAddressCode: Code[10];
        RemitToAddressCode: Code[10];
    begin
        if GPPM00200.Get(Vendor."No.") then begin
            AddressCode := CopyStr(GPSY06000.ADRSCODE.Trim(), 1, MaxStrLen(AddressCode));
            PrimaryAddressCode := CopyStr(GPPM00200.VADDCDPR.Trim(), 1, MaxStrLen(PrimaryAddressCode));
            RemitToAddressCode := CopyStr(GPPM00200.VADCDTRO.Trim(), 1, MaxStrLen(RemitToAddressCode));

            // The Remit To is the preferred account
            if AddressCode = RemitToAddressCode then
                ShouldSetAsPrimaryAccount := true
            else
                if AddressCode = PrimaryAddressCode then begin
                    // If the Vendor does not have a Remit To account, then use the Primary account instead
                    SearchGPSY06000.SetRange("CustomerVendor_ID", Vendor."No.");
                    SearchGPSY06000.SetRange("ADRSCODE", RemitToAddressCode);
                    SearchGPSY06000.SetRange("INACTIVE", false);
                    if SearchGPSY06000.IsEmpty() then
                        ShouldSetAsPrimaryAccount := true;
                end;
        end;

        if ShouldSetAsPrimaryAccount then begin
            Vendor.Validate(Vendor."Preferred Bank Account Code", GPSY06000.EFTBankCode);
            Vendor.Modify(true);
        end;
    end;

    procedure MigrateVendorClasses()
    var
        GPCompanyAdditionalSettings: Record "GP Company Additional Settings";
        GPPM00200: Record "GP PM00200";
        GPPM00100: Record "GP PM00100";
        VendorPostingGroup: Record "Vendor Posting Group";
        Vendor: Record Vendor;
        HelperFunctions: Codeunit "Helper Functions";
        ClassId: Text[20];
        AccountNumber: Code[20];
    begin
        if not GPPM00200.FindSet() then
            exit;

        if not GPCompanyAdditionalSettings.GetMigrateVendorClasses() then
            exit;

        repeat
            Clear(GPPM00100);
            Clear(VendorPostingGroup);

#pragma warning disable AA0139
            ClassId := GPPM00200.VNDCLSID.Trim();
#pragma warning restore AA0139            
            if ClassId <> '' then
                if Vendor.Get(GPPM00200.VENDORID) then begin
                    if not VendorPostingGroup.Get(ClassId) then
                        if GPPM00100.Get(ClassId) then begin
                            VendorPostingGroup.Validate("Code", ClassId);
                            VendorPostingGroup.Validate("Description", GPPM00100.VNDCLDSC);

                            // Payables Account
                            AccountNumber := HelperFunctions.GetGPAccountNumberByIndex(GPPM00100.PMAPINDX);
                            if AccountNumber <> '' then begin
                                HelperFunctions.EnsureAccountHasGenProdPostingAccount(AccountNumber);
                                VendorPostingGroup.Validate("Payables Account", AccountNumber);
                            end;

                            // Service Charge Acc.
                            AccountNumber := HelperFunctions.GetGPAccountNumberByIndex(GPPM00100.PMFINIDX);
                            if AccountNumber <> '' then begin
                                HelperFunctions.EnsureAccountHasGenProdPostingAccount(AccountNumber);
                                VendorPostingGroup.Validate("Service Charge Acc.", AccountNumber);
                            end;

                            // Payment Disc. Debit Acc.
                            AccountNumber := HelperFunctions.GetGPAccountNumberByIndex(GPPM00100.PMDTKIDX);
                            if AccountNumber <> '' then begin
                                HelperFunctions.EnsureAccountHasGenProdPostingAccount(AccountNumber);
                                VendorPostingGroup.Validate("Payment Disc. Debit Acc.", AccountNumber);
                            end;

                            // Payment Disc. Credit Acc.
                            AccountNumber := HelperFunctions.GetGPAccountNumberByIndex(GPPM00100.PMDAVIDX);
                            if AccountNumber <> '' then begin
                                HelperFunctions.EnsureAccountHasGenProdPostingAccount(AccountNumber);
                                VendorPostingGroup.Validate("Payment Disc. Credit Acc.", AccountNumber);
                            end;

                            // Payment Tolerance Debit Acc.
                            // Payment Tolerance Credit Acc.
                            AccountNumber := HelperFunctions.GetGPAccountNumberByIndex(GPPM00100.PMWRTIDX);
                            if AccountNumber <> '' then begin
                                HelperFunctions.EnsureAccountHasGenProdPostingAccount(AccountNumber);
                                VendorPostingGroup.Validate("Payment Tolerance Debit Acc.", AccountNumber);
                                VendorPostingGroup.Validate("Payment Tolerance Credit Acc.", AccountNumber);
                            end;

                            VendorPostingGroup.Insert();
                        end;

                    Vendor.Validate("Vendor Posting Group", ClassId);
                    Vendor.Modify(true);
                end;
        until GPPM00200.Next() = 0;
    end;
}