module spi_master_tb;
   parameter int clk_rate = 400000;
   time		 period = 1s/clk_rate;

   parameter int CLOCK_POLARITY = 1;
   parameter int CLOCK_PHASE    = 0;
   parameter int MSB_FIRST      = 1;
   parameter int RST_LEVEL      = 0;

   logic	 clk  = 0;
   logic	 rstn = 0;

   logic	 m_tvalid;
   logic	 m_tready;
   logic [31:0]  m_tdata;
   logic	 m_tlast;

   logic	 s_tvalid;
   logic	 s_tready;
   logic [31:0]  s_tdata;
   logic	 s_tlast;

   logic [31:0]  num_bytes;
   logic	 busy;

   wire		 sclk;
   wire		 mosi;
   wire		 miso;
   wire		 ss;

   logic         trig = 0;

   axis_if #(.TDATA_BYTES(1)) m_connector(.aclk(clk), .aresetn(rstn));
   axis_if #(.TDATA_BYTES(1)) s_connector(.aclk(clk), .aresetn(rstn));


   assign m_tvalid = m_connector.tvalid;
   assign m_tready = m_connector.tready;
   assign m_tdata  = m_connector.tdata;
   assign m_tlast  = m_connector.tlast;

   assign s_tvalid = s_connector.tvalid;
   assign s_tready = s_connector.tready;
   assign s_tdata  = s_connector.tdata;
   assign s_tlast  = s_connector.tlast;

   initial begin
      forever begin
	 #(period/2) clk = ~clk;
      end
   end


   initial begin
      repeat(10) #(period);
      rstn <= '1;
      repeat(2) #(period);


      #100ns;
      trig <= '1;
      #(period);
      trig <= '0;

      // Writes
      // axis_master.write_beat();
      // repeat(10) #(period);
      // axis_master.write_beat();

      // $display("============================");
      // $display("======= TEST PASSED! =======");
      // $display("============================");
      // $finish;
   end


   initial begin
      #(1000*period)

      $display("============================");
      $display("======= TEST FAILED! =======");
      $display("============================");
      $finish;
   end


   // BFMs
   spi_slave_bfm   #(.clk_polarity(0), .clk_phase(0)) u_spi_slave(.sclk(sclk), .mosi(mosi), .miso(miso), .ss(ss));
   axis_master_bfm u_axis_master(m_connector);
   axis_slave_bfm  u_axis_slave(s_connector);

   // DUT
   spi_master_wrapper #(
			.CLOCK_POLARITY_G(CLOCK_POLARITY),
			.CLOCK_PHASE_G(CLOCK_PHASE),
			.MSB_FIRST_G(MSB_FIRST),
			.RST_LEVEL_G(RST_LEVEL)
			) dut (
			       .clk_in(clk),
			       .rst_in(rstn),
			       .sclk(sclk),
			       .mosi(mosi),
			       .miso(miso),
			       .cs(ss),
			       .s_axis_tdata(m_connector.tdata),
			       .s_axis_tvalid(m_connector.tvalid),
			       .s_axis_tready(m_connector.tready),
			       .s_axis_tlast(m_connector.tlast),
			       .m_axis_tdata(s_connector.tdata),
			       .m_axis_tvalid(s_connector.tvalid),
			       .m_axis_tready(s_connector.tready),
			       .m_axis_tlast(s_connector.tlast),
			       .trigger(trig),
			       .num_bytes(num_bytes),
			       .busy(busy)
			       );

endmodule // spi_master_tb
