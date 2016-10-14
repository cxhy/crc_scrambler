LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY crc_scrambler IS
GENERIC(N:INTEGER:=8);
PORT(
	  addr : IN STD_LOGIC_VECTOR(20 DOWNTO 0);
	  arst : IN STD_LOGIC;
	  clk : IN STD_LOGIC;
	  data_in : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  data_out : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  in_valid : IN STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  out_valid : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
	  rtl_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);--��RTL������32λCRC����textbench����matlab������CRC��Ƚϣ�ȫ���������ɾ���ö˿�
	  rd : IN STD_LOGIC;
	  wr : IN STD_LOGIC
	  );
END ENTITY;
ARCHITECTURE crc_sc OF crc_scrambler IS
-------------------------------------------------------------
FUNCTION invert (data:STD_LOGIC_VECTOR;addr:STD_LOGIC)RETURN STD_LOGIC_VECTOR IS
VARIABLE temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0);
        BEGIN
        IF(addr='1')THEN
          FOR i IN N-1 DOWNTO 0 LOOP
             temp(N-1-i):=data(i);
          END LOOP;
        ELSE
	          temp:=data;
        END IF;
        RETURN temp;
END FUNCTION;
--���ú���
-------------------------------------------------------------
FUNCTION div(data:STD_LOGIC; reg,poly:STD_LOGIC_VECTOR)RETURN STD_LOGIC_VECTOR IS
VARIABLE div_reg:STD_LOGIC_VECTOR(31 DOWNTO 0);
        BEGIN
          div_reg(0):=data XOR(reg(31)AND poly(0));
		  FOR i IN 0 TO 30 LOOP
          div_reg(1+i):=reg(0+i)XOR(reg(31)AND poly(1+i));
        END LOOP;
        RETURN div_reg;
END FUNCTION;
--CRC���㺯��
--------------------------------------------------------------
FUNCTION mov(reg:STD_LOGIC_VECTOR;data:STD_LOGIC)RETURN STD_LOGIC_VECTOR IS
VARIABLE sc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0);
        BEGIN
          sc_reg(0):=data;
        FOR i IN 1 TO 31 LOOP
          sc_reg(i):=reg(i-1);
        END LOOP;
        RETURN sc_reg;
END FUNCTION;
--��λ����
---------------------------------------------------------------
FUNCTION SC_F(reg,poly:STD_LOGIC_VECTOR)RETURN STD_LOGIC IS
VARIABLE temp:STD_LOGIC:='0';
        BEGIN
        FOR i IN 0 TO 31 LOOP
           temp:=temp XOR (reg(i)AND poly(i));
        END LOOP;
        RETURN temp;
END FUNCTION;
--�������
----------------------------------------------------------------
BEGIN
PROCESS(arst,clk)
VARIABLE middle_data1:STD_LOGIC;--����������ĳ�ͷ���ֵ
VARIABLE middle_data2:STD_LOGIC;--��ų�ͷ���������ݵ����ֵ
VARIABLE sc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'1');--��������32λ�Ĵ���
VARIABLE crc_reg:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--CRC��32λ�Ĵ�������ΪCRC���������ļĴ����ĳ�ֵ��ͬ�����Զ����������Ĵ���
VARIABLE out_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--���ڴӴ��CRC32λ�Ĵ����е�ֵ����������32����
VARIABLE crc_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--��rd��Чʱ����CRC��ֵ������������
VARIABLE out_valid_temp:STD_LOGIC_VECTOR(31 DOWNTO 0):=(OTHERS=>'0');--�洢�����Чλ����rd��Чʱ����
VARIABLE sel:STD_LOGIC_VECTOR(1 DOWNTO 0);--����ѡ����������ģʽ��ӽ���
VARIABLE zero:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--��ֵ0��������λ����ͬ��
VARIABLE data_temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--�洢�������ݲ������ֽ����ֵ�˳�����
VARIABLE data_valid_temp:STD_LOGIC_VECTOR(N-1 DOWNTO 0):=(OTHERS=>'0');--�洢����������Чλ�������ֽ����ֵ�˳�����
VARIABLE L_data_temp:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');--�洢��8λ�������ݣ�����������ǵ�8λʱ�Ƚ���8λ���������ڸ�8λ�����������������������˳��ת��
VARIABLE L_data_valid_temp:STD_LOGIC_VECTOR(7 DOWNTO 0):=(OTHERS=>'0');--�洢��8λ����������Чλ��ͬ��
VARIABLE poly_all:STD_LOGIC_VECTOR(32 DOWNTO 0):=(OTHERS=>'0');--��Ŷ���ʽ
VARIABLE circ_cnt:INTEGER:=0;--�������ڸ�8λ���8λ֮����������
VARIABLE cnt:INTEGER:=33;--��������addr�еĶ���ʽ�Ӹߵ��͸���poly_all
VARIABLE cnt1:INTEGER:=0;--��������ѡ������������ʱ��poly_all�е���Ч����ʽ������λ
VARIABLE cnt2:INTEGER:=0;--��������rd��Чʱ����һ������ʹcrc_tempʱ�ӱ���rd����ʱ��out_temp
VARIABLE poly_wide:INTEGER:=-1;--��������ʽλ������ΪCRCn�Ķ���ʽ��n+1λ�����Խ����ֵ��Ϊ-1
BEGIN
IF(arst='0')THEN
  data_out<=(OTHERS=>'0');
  out_valid<=(OTHERS=>'0');
  rtl_out<=(OTHERS=>'0');
ELSIF(clk='1'AND clk'EVENT)THEN
--------------------------------------------------------
    IF(addr(7 downto 0)/=zero)THEN                      --����addr��7~0��λ�Ƿ�Ϊ1��addr��15~8���еĶ���ʽ����poly_all��
	     cnt:=cnt-8;
        FOR i IN N-1 DOWNTO 0 LOOP
           IF(addr(i)='1')THEN
	          poly_all(cnt+i):=addr(i+8);
				 poly_wide:=poly_wide+1;
			  END IF;
		  END LOOP;
    END IF;
--------------------------------------------------------
    IF(wr='0')THEN                                      --����addr��17~16�������������˳�����Ϊ�Ӹ��ֽڵ���ֱ�ӴӸ�λ����λ
        IF(addr(17)='1')THEN--17��Byte��1��0�ߣ�
		    IF(circ_cnt=0)THEN
			    data_temp:=invert(data_in,addr(16));
			    data_valid_temp:=invert(in_valid,addr(16));
			    circ_cnt:=1;
		    ELSIF(circ_cnt=1)THEN
		       data_temp:=L_data_temp;
			    data_valid_temp:=L_data_valid_temp;
		       L_data_temp:=invert(data_in,addr(16));--16��bit��1��0�ߣ�
			    L_data_valid_temp:=invert(in_valid,addr(16));
			    circ_cnt:=0;
		    END IF;
        ELSE
	       data_temp:=invert(data_in,addr(16));
			 data_valid_temp:=invert(in_valid,addr(16));
	     END IF;
--------------------------------------------------------
		  IF(addr(18)='0')THEN                            --����addr��18���Ƿ�Ϊ0���ж��Ƿ��������������
		    sel:=addr(20)&addr(19);                       --����addr��20~19���ж�������ģʽ
	       FOR i IN 0 TO 32 LOOP
	          poly_all:=poly_all(31 DOWNTO 0)& poly_all(32);
	          cnt1:=cnt1+1;
	          IF(cnt1=poly_wide)THEN
	          EXIT;
	          END IF;
		    END LOOP;--������ʽ��λ���Լӵ�������Ϊ������ʽС��32��ʱ��CRC������ʽ����poly_all�ĸ�λ�Ƚϼ��㷽�㣬�������������λ�ȽϷ���
	       FOR i IN N-1 DOWNTO 0 LOOP
	          IF(data_valid_temp(i)='1')THEN
	             middle_data1:=SC_F(sc_reg,poly_all);
		          middle_data2:=middle_data1 XOR data_temp(i);
		          CASE sel IS
		              WHEN "11" => sc_reg:=mov(sc_reg,middle_data2);--ģʽ������
					     WHEN "10" => sc_reg:=mov(sc_reg,data_temp(i));  --ģʽ������
		              WHEN "01" => sc_reg:=mov(sc_reg,middle_data1);--ģʽһ����
		              WHEN "00" => sc_reg:=mov(sc_reg,middle_data1);--ģʽһ����
					     WHEN OTHERS => NULL;
		          END CASE;
		         out_temp(i):=middle_data2;
		         out_valid_temp(i):='1';
		       ELSE
		         out_temp(i):='0';
		         out_valid_temp(i):='0';
		       END IF;
		    END LOOP;

	     ELSE
--------------------------------------------------------
		    FOR i IN N-1 DOWNTO 0 LOOP                    --���addr��18��Ϊ1�����CRC����
		       IF(data_valid_temp(i)='1')THEN
		          crc_reg:=div(data_temp(i),crc_reg,poly_all);
		       END IF;
		    END LOOP;
					 out_temp:=crc_reg;
			 FOR i IN 0 TO 31 LOOP
			       out_temp:=div(zero(0),out_temp,poly_all);
		    END LOOP;
        END IF;
--------------------------------------------------------
		END IF;
	 IF(addr(18)='1')THEN                                --�����ݴ��ݸ�����˿�
	   IF(rd='0')THEN                                    --��ѡ��CRC����ʱ�������rd���ƣ���rdΪ�͵�ƽʱ�������ÿ��8λ�����wr��Ϊ0��rd��Ϊ0�����ʱ�䣨������wrΪ0�����ʱ�䣩������˿��������Ч���ݵ�CRC��
		  IF(cnt2=0)THEN
		    crc_temp:=out_temp;
			 cnt2:=cnt2+1;
		  END IF;
		  FOR i IN N-1 DOWNTO 0 LOOP
           IF(cnt1<poly_wide)THEN
	        	 data_out(i)<= crc_temp(31-cnt1);
				 out_valid(i)<='1';
				 cnt1:=cnt1+1;
			  ELSE
			    data_out(i)<='0';
	          out_valid(i)<='0';
			  END IF;
		  END LOOP;
		END IF;
	 ELSE
	 data_out<=out_temp(7 DOWNTO 0);                  --��ѡ������������ʱ���������rd���ƣ�����������������ʱ������Ӻ�һ������Ҳ���������
	 out_valid<=out_valid_temp(7 DOWNTO 0);
	 END IF;
	 rtl_out<=crc_temp;
--------------------------------------------------------
END IF;
END PROCESS;
END ARCHITECTURE;
