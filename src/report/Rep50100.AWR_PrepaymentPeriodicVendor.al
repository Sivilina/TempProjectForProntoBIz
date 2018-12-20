report 50100 "AWR_Prepayment Periodic Vendor"
{
    // version RA2

    // //!!PETER> 05.06.2018 AW16560

    Caption = 'Set\Reset as prepayment vendor ledger entries';
    Permissions = TableData "Cust. Ledger Entry" = rimd,
                  TableData "Sales Invoice Header" = rim,
                  TableData "Sales Invoice Line" = rim;
    ProcessingOnly = true;

    dataset
    {
        dataitem("Vendor Ledger Entry"; "Vendor Ledger Entry")
        {
            DataItemTableView = SORTING ("Entry No.") ORDER(Ascending) WHERE ("Document Type" = CONST (Payment), Open = CONST (true));
            RequestFilterFields = "Entry No.", "Vendor No.", "Posting Date", "Document No.";

            trigger OnAfterGetRecord()
            begin
                ProcessSingleVLE("Vendor Ledger Entry");
            end;

            trigger OnPreDataItem()
            begin
                SetRange(Prepayment, PrepaymentForPostingType);
            end;
        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {
                group(Settings)
                {
                    Caption = 'Settings';
                    field(oPostingType; oPostingType)
                    {
                        Caption = 'Posting Type';
                        OptionCaption = ',Set Prepayment,Reset Prepayment';
                        ShowMandatory = true;
                    }
                    field(dPostingDate; dPostingDate)
                    {
                        Caption = 'Posting Date';
                    }
                    field(cPostingDocumentNo; cPostingDocumentNo)
                    {
                        Caption = 'Document No.';
                    }
                    field(bPreviewMode; bPreviewMode)
                    {
                        Caption = 'Preview';
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    trigger OnPreReport()
    begin
        CheckPostingType;
        GetSetup;
        GetPrepaymentForPostingType;
    end;

    var
        oPostingType: Option ,"Set Prepayment","Reset Prepayment";
        dPostingDate: Date;
        cPostingDocumentNo: Code[20];
        SourceCodeSetup: Record "Source Code Setup";
        bPreviewMode: Boolean;
        cu11: Codeunit "Gen. Jnl.-Check Line";
        PrepaymentForPostingType: Boolean;
        ERR_NOPOSTINGTYPE: Label 'ENU=Тип учёта не указан;RUS=Тип учёта не указан';
        ERR_NEWPDATELESS: Label 'ENU=Новая дата учета %1 меньше даты учёта %2 исходной операции %3;RUS=Новая дата учета %1 меньше даты учёта %2 исходной операции %3';
        ERR_NEWPDATENOTALLOWED: Label 'ENU=Новая дата учета %1 за пределом разрешённого периода;RUS=Новая дата учета %1 за пределом разрешённого периода';
        dNewPostingDate: Date;
        cNewDocumentNo: Code[20];
        rVPG: Record "Vendor Posting Group";
        cuGenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";

    local procedure CheckPostingType()
    begin
        if oPostingType = 0 then
            Error(ERR_NOPOSTINGTYPE);
    end;

    local procedure GetSetup()
    begin
        SourceCodeSetup.Get;
    end;

    local procedure GetPrepaymentForPostingType()
    begin
        PrepaymentForPostingType := not (oPostingType = oPostingType::"Set Prepayment");
    end;

    local procedure ProcessSingleVLE(var VLE: Record "Vendor Ledger Entry")
    begin
        VLE.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
        if VLE."Remaining Amount" = 0 then
            exit;

        dNewPostingDate := GetNewPostingDate(VLE);
        cNewDocumentNo := GetNewDocumentNo(VLE);

        ValidateSingleVLE(VLE);
        MakePrepaymentSingleVLE(VLE);
    end;

    local procedure ValidateSingleVLE(var VLE: Record "Vendor Ledger Entry")
    begin
        VLE.TestField(Open, true);
        VLE.TestField("Document Type", VLE."Document Type"::Payment);
        VLE.TestField(Prepayment, PrepaymentForPostingType);
        ValidatePostingDate(VLE);
        ValidateVPG(VLE);
    end;

    local procedure ValidatePostingDate(var VLE: Record "Vendor Ledger Entry")
    begin
        if dNewPostingDate < VLE."Posting Date" then
            Error(StrSubstNo(ERR_NEWPDATELESS, dNewPostingDate, VLE."Posting Date", VLE."Entry No."));
        if cu11.DateNotAllowed(dNewPostingDate) then
            Error(StrSubstNo(ERR_NEWPDATENOTALLOWED, dNewPostingDate));
    end;

    local procedure ValidateVPG(var VLE: Record "Vendor Ledger Entry")
    begin
        if VLE."Vendor Posting Group" <> rVPG.Code then
            rVPG.Get(VLE."Vendor Posting Group");
        rVPG.TestField("Payables Account");
        rVPG.TestField("Prepayment Account");
    end;

    local procedure GetNewPostingDate(var VLE: Record "Vendor Ledger Entry"): Date
    begin
        if dPostingDate = 0D then
            exit(VLE."Posting Date")
        else
            exit(dPostingDate);
    end;

    local procedure GetNewDocumentNo(var VLE: Record "Vendor Ledger Entry"): Code[20]
    begin
        if cPostingDocumentNo = '' then
            exit(VLE."Document No.")
        else
            exit(cPostingDocumentNo);
    end;

    local procedure MakePrepaymentSingleVLE(var VLE: Record "Vendor Ledger Entry")
    var
        nPostingType: array[2] of Integer;
        nDocumentType: array[2] of Integer;
        cDocumentNo: array[2] of Code[20];
        bPrepayment: array[2] of Boolean;
        fAmount: array[2] of Decimal;
        fAmountLCY: array[2] of Decimal;
        nApplyToDocType: array[2] of Integer;
        cApplyToDocNo: array[2] of Code[20];
        i: Integer;
    begin
        case oPostingType of
            oPostingType::"Set Prepayment":
                begin
                    nPostingType[1] := 1;
                    nDocumentType[1] := 0;
                    cDocumentNo[1] := cNewDocumentNo;
                    fAmount[1] := (-1) * VLE."Remaining Amount";
                    fAmountLCY[1] := (-1) * VLE."Remaining Amt. (LCY)";
                    nApplyToDocType[1] := VLE."Document Type";
                    cApplyToDocNo[1] := VLE."Document No.";

                    nPostingType[2] := 1;
                    nDocumentType[2] := 1;
                    cDocumentNo[2] := cNewDocumentNo;
                    bPrepayment[2] := true;
                    fAmount[2] := VLE."Remaining Amount";
                    fAmountLCY[2] := VLE."Remaining Amt. (LCY)";
                end;
            oPostingType::"Reset Prepayment":
                begin
                    nPostingType[1] := 2;
                    nDocumentType[1] := 0;
                    cDocumentNo[1] := cNewDocumentNo;
                    bPrepayment[1] := true;
                    fAmount[1] := (-1) * VLE."Remaining Amount";
                    fAmountLCY[1] := (-1) * VLE."Remaining Amt. (LCY)";
                    nApplyToDocType[1] := VLE."Document Type";
                    cApplyToDocNo[1] := VLE."Document No.";

                    nPostingType[2] := 1;
                    nDocumentType[2] := VLE."Document Type";
                    cDocumentNo[2] := cNewDocumentNo;
                    fAmount[2] := VLE."Remaining Amount";
                    fAmountLCY[2] := VLE."Remaining Amt. (LCY)";
                end;
        end;

        for i := 1 to 2 do
            PostGenJnlVLE(VLE, nPostingType[i], nDocumentType[i], cDocumentNo[i], bPrepayment[i], fAmount[i], fAmountLCY[i], nApplyToDocType[i], cApplyToDocNo[i]);
    end;

    local procedure PostGenJnlVLE(var VLE: Record "Vendor Ledger Entry"; PostingType: Integer; DocumentType: Integer; DocumentNo: Code[20]; Prepayment: Boolean; Amount: Decimal; AmountLCY: Decimal; ApplyToDocType: Integer; ApplyToDocNo: Code[20])
    var
        rGenJnl: Record "Gen. Journal Line";
    begin
        rGenJnl.Init;
        rGenJnl."Posting Date" := dNewPostingDate;
        rGenJnl."Account Type" := rGenJnl."Account Type"::Vendor;
        rGenJnl.Validate("Account No.", VLE."Vendor No.");
        rGenJnl."Posting Group" := VLE."Vendor Posting Group";
        rGenJnl.Validate("Currency Code", VLE."Currency Code");
        rGenJnl."System-Created Entry" := true;
        rGenJnl."Source Code" := SourceCodeSetup."Vendor Prepayments";
        rGenJnl.Validate("Shortcut Dimension 1 Code", VLE."Global Dimension 1 Code");
        rGenJnl.Validate("Shortcut Dimension 2 Code", VLE."Global Dimension 2 Code");
        rGenJnl."Prepayment Status" := PostingType;
        rGenJnl."Prepayment Document No." := DocumentNo;
        rGenJnl."External Document No." := VLE."External Document No.";
        rGenJnl."Agreement No." := VLE."Agreement No.";

        rGenJnl."Document Type" := DocumentType;
        rGenJnl."Document No." := DocumentNo;
        rGenJnl.Description := VLE.Description;
        rGenJnl.Prepayment := Prepayment;

        if ApplyToDocNo <> '' then begin
            rGenJnl."Applies-to Doc. Type" := ApplyToDocType;
            rGenJnl."Applies-to Doc. No." := ApplyToDocNo;
        end;

        rGenJnl.Validate(Amount, Amount);
        rGenJnl.Validate("Amount (LCY)", AmountLCY);
        // cuGenJnlPostLine.SetPreviewMode(bPreviewMode);
        cuGenJnlPostLine.RunWithCheck(rGenJnl);
    end;

    procedure SetPreviewMode(PreviewMode: Boolean)
    begin
        bPreviewMode := PreviewMode;
    end;
}

