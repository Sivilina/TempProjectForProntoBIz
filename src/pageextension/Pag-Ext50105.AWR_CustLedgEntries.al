pageextension 50105 "AWR_CustLedgEntries" extends "Customer Ledger Entries"
{
    actions

    {

        addafter(Action1470000)
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
                    rСLE: Record "Cust. Ledger Entry";
                begin
                    //-001
                    rСLE.SETRANGE("Entry No.", "Entry No.");
                    rСLE.SETRANGE("Customer No.", "Customer No.");
                    REPORT.RUN(REPORT::"AWR_Prepayment Periodic Cust", TRUE, TRUE, rСLE);
                    //+001
                end;
            }

        }

    }



}

