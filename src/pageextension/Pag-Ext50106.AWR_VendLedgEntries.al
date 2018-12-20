pageextension 50106 "AWR_VendLedgEntries" extends "Vendor Ledger Entries"
{
    actions

    {

        addafter(Action1210000)
        {

            action("AWR_ReturnPrepayment")

            {
                ApplicationArea = All;
                Image = ChangeStatus;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                CaptionML = ENU = 'Reset Prepayment',
                    RUS = 'Изменить статус предоплаты';
                trigger OnAction();
                var
                    rVLE: Record "Vendor Ledger Entry";
                begin
                    //-001
                    rVLE.SETRANGE("Entry No.", "Entry No.");
                    rVLE.SETRANGE("Vendor No.", "Vendor No.");
                    REPORT.RUN(REPORT::"AWR_Prepayment Periodic Vendor", TRUE, TRUE, rVLE);
                    //+001
                end;
            }

        }

    }



}

