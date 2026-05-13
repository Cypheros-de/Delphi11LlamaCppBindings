object FormMain: TFormMain
  Left = 200
  Top = 100
  Caption = 'VCL Vision - Local LLM with Image Input'
  ClientHeight = 760
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Splitter1: TSplitter
    Left = 220
    Top = 41
    Height = 697
  end
  object sbStatus: TStatusBar
    Left = 0
    Top = 738
    Width = 1100
    Height = 22
    Panels = <
      item
        Text = 'No model loaded'
        Width = 450
      end
      item
        Text = 'Ready'
        Width = 250
      end
      item
        Width = 120
      end
      item
        Width = 180
      end>
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      1100
      41)
    object lblDir: TLabel
      Left = 8
      Top = 13
      Width = 87
      Height = 15
      Caption = 'Model directory:'
    end
    object edtDir: TEdit
      Left = 100
      Top = 9
      Width = 770
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
    end
    object btnBrowse: TButton
      Left = 878
      Top = 8
      Width = 30
      Height = 25
      Anchors = [akTop, akRight]
      Caption = '...'
      TabOrder = 1
      OnClick = btnBrowseClick
    end
    object btnReload: TButton
      Left = 915
      Top = 8
      Width = 110
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Refresh'
      TabOrder = 2
      OnClick = btnReloadClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 41
    Width = 220
    Height = 697
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblModels: TLabel
      Left = 0
      Top = 0
      Width = 220
      Height = 20
      Align = alTop
      AutoSize = False
      Caption = 'Models (*.gguf):'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lbModels: TListBox
      Left = 0
      Top = 20
      Width = 220
      Height = 677
      Align = alClient
      ItemHeight = 15
      TabOrder = 0
      OnDblClick = lbModelsDblClick
    end
  end
  object pnlMain: TPanel
    Left = 223
    Top = 41
    Width = 877
    Height = 697
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pnlSettings: TPanel
      Left = 0
      Top = 0
      Width = 877
      Height = 190
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object gbSettings: TGroupBox
        Left = 0
        Top = 0
        Width = 877
        Height = 190
        Align = alClient
        Caption = ' Settings '
        TabOrder = 0
        DesignSize = (
          877
          190)
        object lblSystemPrompt: TLabel
          Left = 8
          Top = 18
          Width = 84
          Height = 15
          Caption = 'System prompt:'
        end
        object lblGpuLayers: TLabel
          Left = 8
          Top = 108
          Width = 59
          Height = 15
          Caption = 'GPU layers:'
        end
        object lblCtx: TLabel
          Left = 148
          Top = 108
          Width = 44
          Height = 15
          Caption = 'Context:'
        end
        object lblMmproj: TLabel
          Left = 8
          Top = 144
          Width = 65
          Height = 15
          Caption = 'mmproj file:'
        end
        object memSystemPrompt: TMemo
          Left = 8
          Top = 36
          Width = 857
          Height = 58
          Anchors = [akLeft, akTop, akRight]
          Lines.Strings = (
            
              'You are a helpful assistant. Describe images accurately and answ' +
              'er questions about them.')
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object edtGpuLayers: TEdit
          Left = 90
          Top = 104
          Width = 50
          Height = 23
          TabOrder = 1
          Text = '-1'
        end
        object edtCtx: TEdit
          Left = 196
          Top = 104
          Width = 65
          Height = 23
          TabOrder = 2
          Text = '4096'
        end
        object cbFlashAttn: TCheckBox
          Left = 269
          Top = 106
          Width = 115
          Height = 19
          Caption = 'Flash attention'
          Checked = True
          State = cbChecked
          TabOrder = 3
        end
        object cbTypeKV: TCheckBox
          Left = 390
          Top = 106
          Width = 118
          Height = 19
          Caption = 'Q8_0 KV-Cache'
          Checked = True
          State = cbChecked
          TabOrder = 4
        end
        object cbOffloadKQV: TCheckBox
          Left = 514
          Top = 106
          Width = 110
          Height = 19
          Caption = 'Offload KQV'
          Checked = True
          State = cbChecked
          TabOrder = 5
        end
        object btnNewChat: TButton
          Left = 630
          Top = 102
          Width = 90
          Height = 27
          Caption = 'New Chat'
          Enabled = False
          TabOrder = 6
          OnClick = btnNewChatClick
        end
        object btnLoad: TButton
          Left = 726
          Top = 102
          Width = 67
          Height = 27
          Caption = 'Load'
          TabOrder = 7
          OnClick = btnLoadClick
        end
        object edtMmproj: TEdit
          Left = 90
          Top = 138
          Width = 655
          Height = 23
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 8
          TextHint = 'Path to mmproj.gguf file'
        end
        object btnBrowseMmproj: TButton
          Left = 751
          Top = 138
          Width = 30
          Height = 23
          Anchors = [akTop, akRight]
          Caption = '...'
          TabOrder = 9
          OnClick = btnBrowseMmprojClick
        end
      end
    end
    object pnlImage: TPanel
      Left = 0
      Top = 190
      Width = 877
      Height = 150
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 1
      object imgPreview: TImage
        Left = 8
        Top = 8
        Width = 180
        Height = 134
        Proportional = True
        Stretch = True
      end
      object lblImageInfo: TLabel
        Left = 196
        Top = 8
        Width = 98
        Height = 15
        Caption = 'No image selected'
      end
      object btnSelectImage: TButton
        Left = 196
        Top = 32
        Width = 140
        Height = 27
        Caption = 'Select image...'
        Enabled = False
        TabOrder = 0
        OnClick = btnSelectImageClick
      end
      object btnClearImage: TButton
        Left = 344
        Top = 32
        Width = 90
        Height = 27
        Caption = 'Clear'
        Enabled = False
        TabOrder = 1
        OnClick = btnClearImageClick
      end
    end
    object pnlInput: TPanel
      Left = 0
      Top = 607
      Width = 877
      Height = 90
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 2
      object pnlButtons: TPanel
        Left = 767
        Top = 0
        Width = 110
        Height = 90
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 0
        object btnSend: TButton
          Left = 8
          Top = 10
          Width = 95
          Height = 30
          Caption = 'Send'
          Default = True
          Enabled = False
          TabOrder = 0
          OnClick = btnSendClick
        end
        object btnCancel: TButton
          Left = 8
          Top = 48
          Width = 95
          Height = 30
          Caption = 'Cancel'
          Enabled = False
          TabOrder = 1
          OnClick = btnCancelClick
        end
      end
      object memInput: TMemo
        Left = 0
        Top = 0
        Width = 767
        Height = 90
        Align = alClient
        Enabled = False
        Lines.Strings = (
          '')
        ScrollBars = ssVertical
        TabOrder = 1
        OnKeyDown = memInputKeyDown
      end
    end
    object memChat: TMemo
      Left = 0
      Top = 340
      Width = 877
      Height = 267
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 3
    end
  end
  object Llama1: TLlama
    Settings.NGpuLayers = 0
    Settings.SplitMode = LLAMA_SPLIT_MODE_LAYER
    Settings.MainGpu = 0
    Settings.VocabOnly = False
    Settings.UseMMap = True
    Settings.UseMLock = False
    Settings.Seed = -1
    Settings.NCtx = 512
    Settings.NBatch = 512
    Settings.NUBatch = 512
    Settings.NThreads = 0
    Settings.NThreadsBatch = 0
    Settings.YarnExtFactor = -1.000000000000000000
    Settings.YarnAttnFactor = 1.000000000000000000
    Settings.YarnBetaFast = 32.000000000000000000
    Settings.YarnBetaSlow = 1.000000000000000000
    Settings.YarnOrigCtx = 0
    Settings.LogitsAll = False
    Settings.Embeddings = False
    Settings.OffloadKQV = True
    Settings.FlashAttn = False
    Settings.LastNTokensSize = 64
    Settings.LoraScale = 1.000000000000000000
    Settings.NUMA = GGML_NUMA_STRATEGY_DISABLED
    Settings.TypeK = GGML_TYPE_F32
    Settings.TypeV = GGML_TYPE_F32
    Settings.SPMInfill = False
    Settings.Verbose = True
    Settings.NSeqMax = 1
    Left = 800
    Top = 56
  end
  object dlgOpenModel: TOpenDialog
    Filter = 'GGUF files (*.gguf)|*.gguf|All files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 800
    Top = 112
  end
  object dlgOpenImage: TOpenDialog
    Filter = 
      'Image files (*.jpg;*.jpeg;*.png;*.bmp)|*.jpg;*.jpeg;*.png;*.bmp|' +
      'All files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 800
    Top = 168
  end
end
