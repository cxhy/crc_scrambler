

fileTxIn = fopen('D:\work\crc_scrambler\data_send.dat','w');
fileTxCRCOut = fopen('D:\work\crc_scrambler\txCRCOut.dat','w');
%fileRxIn = fopen('rxIn.dat','w');
%fileRxCRCOut = fopen('rxCRCOut.dat','w');
fileTxValid = fopen('D:\work\crc_scrambler\valid_send.dat','w');


n=104;%input data length
s=randperm(104);
m=s(1);%����һ��������ȵ�m��Ϊ������Ч���ݵĸ��� ȡ����ĵ�һ��Ԫ��

TxDataIn=randperm(n);
TxValidIn=[ones(1,m) zeros(1,n-m)];%������Чλ �ֱ�����1��m�е�1��TxValidIn����
                                   %ͬʱ����1��n-m�е�0��TxValidIn����

TxOutputCRC = CRC3_gen(TxDataIn,m);

%RxDataIn=[TxDataIn TxOutputCRC];

%RxOutputCRC=CRC5_gen(RxDataIn,m);

fprintf(fileTxIn,'%d\n',TxDataIn);
fprintf(fileTxCRCOut,'%d\n',TxOutputCRC);
%fprintf(fileRxIn,'%d\n',RxDataIn);
%fprintf(fileRxCRCOut,'%d\n',RxOutputCRC);
fprintf(fileTxValid,'%d\n',TxValidIn);

fclose(fileTxIn);
fclose(fileTxCRCOut);
%fclose(fileRxIn);
%fclose(fileRxCRCOut);
fclose(fileTxValid);

cd D:\work\crc_scrambler
!auto_crc.bat


