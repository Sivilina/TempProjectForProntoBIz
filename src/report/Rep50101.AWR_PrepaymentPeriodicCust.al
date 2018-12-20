report 50101 "AWR_Prepayment Periodic Cust"
{
    // version RA2

    // //!!PETER> 05.06.2018 AW16560

    Caption = 'Set\Reset as prepayment customer ledger entries';
    Permissions = TableData "Cust. Ledger Entry" = rimd,
                  TableData "Sales Invoice Header" = rim,
                  TableData "Sales Invoice Line" = rim;
    ProcessingOnly = true;

    dataset
    {
        dataitem("Cust. Ledger Entry"; "Cust. Ledger Entry")
        {
            DataItemTableView = SORTING ("Entry No.") ORDER(Ascending) WHERE ("Document Type" = CONST (Payment), Open = CONST (true));
            RequestFilterFields = "Entry No.", "Customer No.", "No. Series", "Posting Date", "Document No.";

            trigger OnAfterGetRecord()
            begin
                ProcessSingleVLE("Cust. Ledger Entry");
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
        rVPG: Record "Customer Posting Group";
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

    local procedure ProcessSingleVLE(var CLE: Record "Cust. Ledger Entry")
    begin
        CLE.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
        if CLE."Remaining Amount" = 0 then
            exit;

        dNewPostingDate := GetNewPostingDate(CLE);
        cNewDocumentNo := GetNewDocumentNo(CLE);

        ValidateSingleVLE(CLE);
        MakePrepaymentSingleVLE(CLE);
    end;

    local procedure ValidateSingleVLE(var CLE: Record "Cust. Ledger Entry")
    begin
        CLE.TestField(Open, true);
        CLE.TestField("Document Type", CLE."Document Type"::Payment);
        CLE.TestField(Prepayment, PrepaymentForPostingType);
        ValidatePostingDate(CLE);
        ValidateVPG(CLE);
    end;

    local procedure ValidatePostingDate(var CLE: Record "Cust. Ledger Entry")
    begin
        if dNewPostingDate < CLE."Posting Date" then
            Error(StrSubstNo(ERR_NEWPDATELESS, dNewPostingDate, CLE."Posting Date", CLE."Entry No."));
        if cu11.DateNotAllowed(dNewPostingDate) then
            Error(StrSubstNo(ERR_NEWPDATENOTALLOWED, dNewPostingDate));
    end;

    local procedure ValidateVPG(var CLE: Record "Cust. Ledger Entry")
    begin
        if CLE."Customer Posting Group" <> rVPG.Code then
            rVPG.Get(CLE."Customer Posting Group");
        rVPG.TestField("Receivables Account");
        rVPG.TestField("Prepayment Account");
    end;

    local procedure GetNewPostingDate(var CLE: Record "Cust. Ledger Entry"): Date
    begin
        if dPostingDate = 0D then
            exit(CLE."Posting Date")
        else
            exit(dPostingDate);
    end;

    local procedure GetNewDocumentNo(var CLE: Record "Cust. Ledger Entry"): Code[20]
    begin
        if cPostingDocumentNo = '' then
            exit(CLE."Document No.")
        else
            exit(cPostingDocumentNo);
    end;

    local procedure MakePrepaymentSingleVLE(var CLE: Record "Cust. Ledger Entry")
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
                    fAmount[1] := (-1) * CLE."Remaining Amount";
                    fAmountLCY[1] := (-1) * CLE."Remaining Amt. (LCY)";
                    nApplyToDocType[1] := CLE."Document Type";
                    cApplyToDocNo[1] := CLE."Document No.";

                    nPostingType[2] := 1;
                    nDocumentType[2] := 1;
                    cDocumentNo[2] := cNewDocumentNo;
                    bPrepayment[2] := true;
                    fAmount[2] := CLE."Remaining Amount";
                    fAmountLCY[2] := CLE."Remaining Amt. (LCY)";
                end;
            oPostingType::"Reset Prepayment":
                begin
                    nPostingType[1] := 2;
                    nDocumentType[1] := 0;
                    cDocumentNo[1] := cNewDocumentNo;
                    bPrepayment[1] := true;
                    fAmount[1] := (-1) * CLE."Remaining Amount";
                    fAmountLCY[1] := (-1) * CLE."Remaining Amt. (LCY)";
                    nApplyToDocType[1] := CLE."Document Type";
                    cApplyToDocNo[1] := CLE."Document No.";

                    nPostingType[2] := 1;
                    nDocumentType[2] := CLE."Document Type";
                    cDocumentNo[2] := cNewDocumentNo;
                    fAmount[2] := CLE."Remaining Amount";
                    fAmountLCY[2] := CLE."Remaining Amt. (LCY)";
                end;
        end;

        for i := 1 to 2 do
            PostGenJnlVLE(CLE, nPostingType[i], nDocumentType[i], cDocumentNo[i], bPrepayment[i], fAmount[i], fAmountLCY[i], nApplyToDocType[i], cApplyToDocNo[i]);
    end;

    local procedure PostGenJnlVLE(var CLE: Record "Cust. Ledger Entry"; PostingType: Integer; DocumentType: Integer; DocumentNo: Code[20]; Prepayment: Boolean; Amount: Decimal; AmountLCY: Decimal; ApplyToDocType: Integer; ApplyToDocNo: Code[20])
    var
        rGenJnl: Record "Gen. Journal Line";
    begin
        rGenJnl.Init;
        rGenJnl."Posting Date" := dNewPostingDate;
        rGenJnl."Account Type" := rGenJnl."Account Type"::Customer;
        rGenJnl.Validate("Account No.", CLE."Customer No.");
        rGenJnl."Posting Group" := CLE."Customer Posting Group";
        rGenJnl.Validate("Currency Code", CLE."Currency Code");
        rGenJnl."System-Created Entry" := true;
        rGenJnl."Source Code" := SourceCodeSetup."Customer Prepayments";
        rGenJnl.Validate("Shortcut Dimension 1 Code", CLE."Global Dimension 1 Code");
        rGenJnl.Validate("Shortcut Dimension 2 Code", CLE."Global Dimension 2 Code");
        rGenJnl."Prepayment Status" := PostingType;
        rGenJnl."Prepayment Document No." := DocumentNo;
        rGenJnl."External Document No." := CLE."External Document No.";
        rGenJnl."Agreement No." := CLE."Agreement No.";

        rGenJnl."Document Type" := DocumentType;
        rGenJnl."Document No." := DocumentNo;
        rGenJnl.Description := CLE.Description;
        rGenJnl.Prepayment := Prepayment;

        if ApplyToDocNo <> '' then begin
            rGenJnl."Applies-to Doc. Type" := ApplyToDocType;
            rGenJnl."Applies-to Doc. No." := ApplyToDocNo;
        end;

        rGenJnl.Validate(Amount, Amount);
        rGenJnl.Validate("Amount (LCY)", AmountLCY);
        //cuGenJnlPostLine.SetPreviewMode(bPreviewMode);
        cuGenJnlPostLine.RunWithCheck(rGenJnl);
    end;

    procedure SetPreviewMode(PreviewMode: Boolean)
    begin
        bPreviewMode := PreviewMode;
    end;
}

