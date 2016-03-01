

fileTxIn = fopen('data_send.dat','w');
fileTxCRCOut = fopen('txCRCOut.dat','w');
fileRxIn = fopen('rxIn.dat','w');
fileRxCRCOut = fopen('rxCRCOut.dat','w');


n=100;%input data length

TxDataIn=randperm(n);

TxOutputCRC = CRC5_gen(TxDataIn);

RxDataIn=[TxDataIn TxOutputCRC];

fileTxValid = fopen('valid_send.dat','w');
s=randperm(n);
m=s(1);
TxValidIn=[ones(1,m) zeros(1,n-m)];
fprintf(fileTxValid,'%d\n',TxValidIn);
fclose(fileTxValid);

RxOutputCRC=CRC5_gen(RxDataIn);

fprintf(fileTxIn,'%d\n',TxDataIn);
fprintf(fileTxCRCOut,'%d\n',TxOutputCRC);
fprintf(fileRxIn,'%d\n',RxDataIn);
fprintf(fileRxCRCOut,'%d\n',RxOutputCRC);

fclose(fileTxIn);
fclose(fileTxCRCOut);
fclose(fileRxIn);
fclose(fileRxCRCOut);


