function [BER,PER]=RCPC_test_equal_packet(hmany,packet_siz,chnlname,PunctRate,CRC_siz,gain);%Memory,CodeGenerator,PunctCode,CRC_siz)
%BitTot    - upper limit of data bits sent
%packet_siz     - packet size (strictly given)
%parametar - parametar for selected channel type
%PunctRate - string that defines the used RCPC code (defined in text file
%            "punct_codes.txt" (i.e. '1/2', '4/7',...)
%CRC_siz - size in bits of CRC check that is added to each packet 
%
%if 8/N RCPC codes (P=8) and byte size compatible CRC are used then PacketData is
%also byte size compatible, so no truncation or extension is necessary
% -> this is especially convenient if RS column code is to be used

DetectedErr=0;
CRCDetErr=0;
[ch_handle,parametar]=get_channel(chnlname);
parametar.gain=gain;
[Memory,Ib,Kb,t,PN,P,TotRate,PunctInd]=get_RCPC_code(PunctRate);
fprintf('Mother code rate: 1/%d\n',PN/P);
fprintf('Puncturing code rate: %d/%d\n',length(PunctInd),PN);
fprintf('Total rate: %d/%d\n',Ib,Kb);
[PunctIndFull,PacketData,DepunctLen]=Punct_Variables(Memory,Ib,Kb,PN,P,PunctInd,packet_siz,CRC_siz);

fprintf('Data bits in packet: %d\n',PacketData);
fprintf('Number of packets: %d\n',hmany);
fprintf('Transmitted data bits: %d\n',hmany*PacketData);
    
errbit=zeros(1,hmany);
diffvec=zeros(1,PacketData);
for i=1:hmany
 %InPckt=InStream((i-1)*PacketData+1:i*PacketData); 
 InPckt=randint(PacketData,1,2)';
 if CRC_siz==0
     CRC=[];
 else
     CRC=generic_crc(InPckt,CRC_siz);
     %CRC=zeros(1,CRC_siz);
 end;
 %Convolutional encoding + puncturing
 OutputStreamPunct=RCPC_encode([CRC InPckt],Memory,t,P,PunctIndFull); % OutputStreamPunct is bipolar!!
 %AWGN channel - awgn_EsN0 function
 %BSC channel - BSC_BER function
 [OutputStreamPunctCh,parametar]=feval(ch_handle,OutputStreamPunct,parametar); %Power of the signal is now 1, i.e. 0dBW
 %Viterbi decoding
 CRCOutPckt=RCPC_decode(OutputStreamPunctCh,Memory,t,PunctIndFull,DepunctLen,PacketData+CRC_siz);
 %Error detection
 OutPckt=CRCOutPckt(CRC_siz+1:end);
 diffPckt=OutPckt~=InPckt;
 %diffvec=diffvec+diffPckt;
 errbit(i)=sum(diffPckt);
 if CRC_siz>0 %check CRC
  CRC=CRCOutPckt(1:CRC_siz);
  CRCerr=any(generic_crc(OutPckt,CRC_siz)~=CRC);
  DetectedErr=DetectedErr+CRCerr;
  if errbit(i) & CRCerr
   CRCDetErr=CRCDetErr+1;
  end;
 end;
end;
%inderr=find(OutputStream~=InStream);
TotErrors=sum(errbit);
BER=TotErrors/(hmany*PacketData);
if CRC_siz>0
    TotPcktErrors=DetectedErr;
else
    TotPcktErrors=sum(errbit>0);
end;
PER=TotPcktErrors/hmany;
fprintf('\n***Errors Statistics***\n');
fprintf('Errors = %d\nBER = %f\n',TotErrors,BER);
fprintf('Packet errors = %d\nPER = %f\n',TotPcktErrors,PER);
fprintf('(CRC) Correctly detected packet errors = %d\n', CRCDetErr);
fprintf('(CRC) Detected packet errors = %d\n\n', DetectedErr);