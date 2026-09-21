const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
        ShadingType, PageNumber, PageBreak, LevelFormat } = require('docx');

const border = { style: BorderStyle.SINGLE, size: 1, color: "999999" };
const borders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 60, bottom: 60, left: 100, right: 100 };
const headerShading = { fill: "2E75B6", type: ShadingType.CLEAR };
const headerText = (t) => new Paragraph({ alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: t, bold: true, color: "FFFFFF", size: 20, font: "Arial" })] });
const cell = (t, opts = {}) => new TableCell({ borders, margins: cellMargins,
    width: { size: opts.w || 1500, type: WidthType.DXA },
    shading: opts.sh || null,
    children: [new Paragraph({ alignment: opts.align || AlignmentType.LEFT,
        children: [new TextRun({ text: String(t), size: 18, font: "Arial", bold: opts.b || false })] })] });

// ===== 工况汇总表数据 =====
const scenarioHeaders = ['工况类型', '组数', '车速(km/h)', '转向幅值(°)', '横坡(%)', '状态分布'];
const scenarioColW = [1400, 900, 1300, 1300, 1100, 2000];
const scenarioTableW = scenarioColW.reduce((a,b)=>a+b);
const scenarios = [
    ['阶跃转向(SS)', '12', '60~100', '60~180', '0', '安全3/警告1/侧翻8'],
    ['双移线(DLC)', '2', '70~100', '—', '0', '安全0/警告2/侧翻0'],
    ['鱼钩(Fishhook)', '16', '60~90', '90~270', '0', '安全2/警告2/侧翻12'],
    ['横坡叠加(Super)', '7', '80', '90', '-6~+6', '安全0/警告5/侧翻2'],
    ['合计', '37', '60~100', '—', '—', '安全5/警告10/侧翻22'],
];

// ===== 三模型对比数据 =====
const modelHeaders = ['模型', 'RMSE', 'R²', '准确率', '精确率', '召回率', 'F1', 'AUC'];
const modelColW = [1600, 1100, 1100, 1100, 1100, 1100, 1000, 1100];
const modelTableW = modelColW.reduce((a,b)=>a+b);
const models = [
    ['LSTM', '0.0533', '0.9784', '98.92%', '93.39%', '97.62%', '0.955', '0.9979'],
    ['CNN', '0.0521', '0.9794', '98.50%', '89.78%', '98.33%', '0.939', '0.9985'],
    ['CNN-LSTM', '0.0485', '0.9821', '99.28%', '96.68%', '97.14%', '0.969', '0.9988'],
];

const doc = new Document({
    styles: {
        default: { document: { run: { font: "Arial", size: 22 } } },
        paragraphStyles: [
            { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
              run: { size: 32, bold: true, font: "Arial", color: "2E75B6" },
              paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 0 } },
            { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
              run: { size: 26, bold: true, font: "Arial", color: "2E75B6" },
              paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 1 } },
        ]
    },
    numbering: {
        config: [{
            reference: "bullets",
            levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT,
                style: { paragraph: { indent: { left: 720, hanging: 360 } } } }]
        }]
    },
    sections: [{
        properties: {
            page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1200, bottom: 1200, left: 1200 } }
        },
        headers: {
            default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT,
                children: [new TextRun({ text: "TruckSim-Simulink 联合仿真工作汇报", size: 16, color: "888888", font: "Arial" })] })] })
        },
        footers: {
            default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
                children: [new TextRun({ text: "第 ", size: 16, font: "Arial" }),
                    new TextRun({ children: [PageNumber.CURRENT], size: 16, font: "Arial" }),
                    new TextRun({ text: " 页", size: 16, font: "Arial" })] })] })
        },
        children: [
            // Title
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 },
                children: [new TextRun({ text: "七自由度半挂液罐车 TruckSim-Simulink", size: 36, bold: true, font: "Arial", color: "2E75B6" })] }),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 },
                children: [new TextRun({ text: "联合仿真与侧翻预警工作汇报", size: 36, bold: true, font: "Arial", color: "2E75B6" })] }),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 },
                children: [new TextRun({ text: "日期：2026年8月23日", size: 22, color: "666666", font: "Arial" })] }),

            // 1. Overview
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("一、项目概述")] }),
            new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "本项目在TruckSim 2022中建立七自由度(7-DOF)半挂液罐车模型,通过MATLAB/Simulink实现线性等效双摆(LDP)液体晃动模型的联合仿真。设计鱼钩、双移线、阶跃转向及道路横坡等典型危险工况,提取车辆状态数据并计算LTR标签,构建LSTM、CNN、CNN-LSTM三种神经网络实现液罐车侧翻实时预测。", size: 22, font: "Arial"})] }),
            new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: "车辆配置：牵引车 3A Cab Over + 半挂罐车 3A Euro Trailer，液体货物质量20,000kg，充液比70%，总质量34,000kg。", size: 22, font: "Arial"})] }),

            // 2. Workflow
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("二、技术路线与工作流程")] }),
            ...[
                "Step 1: TruckSim 2022中配置七自由度半挂液罐车模型（质心高度1.8m、悬架刚度400N/mm等参数）",
                "Step 2: 设计LDP线性等效双摆液体晃动模型（主摆75%质量+次摆25%质量），在Simulink中搭建闭环反馈架构",
                "Step 3: 设计鱼钩、双移线、阶跃转向三种工况，并叠加道路横坡，共运行37组TruckSim仿真",
                "Step 4: 通过命令行驱动TruckSim仿真，解析VSB二进制结果文件，自动提取时间序列数据",
                "Step 5: 基于垂向轮胎力实时计算LTR标签（|LTR|≥0.7为侧翻风险阈值）",
                "Step 6: 构建滑动窗口序列样本（50步回看→10步预测），训练LSTM/CNN/CNN-LSTM三种侧翻预警模型",
            ].map(t => new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 40 },
                children: [new TextRun({ text: t, size: 20, font: "Arial" })] })),

            // 3. Scenarios
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("三、仿真工况汇总")] }),
            new Paragraph({ spacing: { after: 100 }, children: [new TextRun({ text: "共完成37组TruckSim仿真工况，覆盖鱼钩、双移线、阶跃转向三种工况及道路横坡叠加，车速60-100km/h，安全/警告/侧翻全谱。", size: 22, font: "Arial" })] }),

            new Table({
                width: { size: scenarioTableW, type: WidthType.DXA },
                columnWidths: scenarioColW,
                rows: [
                    new TableRow({ children: scenarioHeaders.map((h,i) => cell(h, {w: scenarioColW[i], sh: headerShading, b: true, align: AlignmentType.CENTER})) }),
                    ...scenarios.map((row, idx) => new TableRow({
                        children: row.map((v,i) => {
                            let sh = null;
                            if (idx === scenarios.length - 1) sh = { fill: "E0E0E0", type: ShadingType.CLEAR };
                            return cell(v, {w: scenarioColW[i], sh, align: i>=1 ? AlignmentType.CENTER : AlignmentType.LEFT, b: idx===scenarios.length-1});
                        })
                    }))
                ]
            }),

            new Paragraph({ spacing: { before: 60, after: 60 }, children: [new TextRun({ text: "注：37组工况中，安全5组、警告10组、侧翻22组。侧翻工况挂车侧倾角均超过77°，LTR达到1.0。鱼钩工况侧向加速度最高达1.28g，是更极限的侧翻激励。", size: 18, color: "666666", font: "Arial", italics: true })] }),

            // 4. Model Results
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("四、侧翻预警模型训练结果")] }),
            new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "基于37组TruckSim仿真数据（18056个序列样本），构建滑动窗口序列（回看50步×5特征，预测10步LTR），训练LSTM、CNN、CNN-LSTM三种神经网络模型。训练集危险样本经平衡采样调整至30%。三模型在测试集上的性能对比如下：", size: 22, font: "Arial"})] }),

            new Table({
                width: { size: modelTableW, type: WidthType.DXA },
                columnWidths: modelColW,
                rows: [
                    new TableRow({ children: modelHeaders.map((h,i) => cell(h, {w: modelColW[i], sh: headerShading, b: true, align: AlignmentType.CENTER})) }),
                    ...models.map((row, idx) => new TableRow({
                        children: row.map((v,i) => {
                            let sh = idx === 2 ? { fill: "D7FFD7", type: ShadingType.CLEAR } : null;
                            return cell(v, {w: modelColW[i], sh, align: i>=1 ? AlignmentType.CENTER : AlignmentType.LEFT, b: idx===2});
                        })
                    }))
                ]
            }),

            new Paragraph({ spacing: { before: 80 }, children: [new TextRun({ text: "CNN-LSTM混合模型综合性能最优，R²=0.9821、F1=0.969、AUC=0.9988、准确率99.28%，四项核心指标全部领先。在数据量充足的情况下，CNN-LSTM充分发挥CNN的局部特征提取与LSTM的时序建模优势，性能优于单一神经网络，与相关文献结论一致。", size: 22, font: "Arial", bold: true})] }),

            // 5. Deliverables
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("五、交付物清单")] }),
            ...[
                ["TruckSim仿真模型", "3A Cab Over + 3A Euro Trailer，七自由度液罐车配置"],
                ["LDP液体晃动模型", "线性等效双摆模型（Simulink子系统 + MATLAB ODE）"],
                ["仿真工况数据集", "37组CSV文件，含Ay/AVz/Roll/Fz等关键变量时间序列"],
                ["LTR标签数据", "ts_dataset.mat（18056样本，5特征×50步序列）"],
                ["LSTM侧翻预测模型", "lstm_ts_model.mat（F1=0.955, R²=0.9784）"],
                ["CNN侧翻预测模型", "cnn_ts_model.mat（F1=0.939, R²=0.9794）"],
                ["CNN-LSTM侧翻预测模型", "cnnlstm_ts_model.mat（F1=0.969, R²=0.9821）"],
                ["模型对比结果", "model_comparison.mat（ROC/AUC评估）"],
                ["消融实验结果", "ablation_results.mat（液体晃动影响分析）"],
                ["批量仿真工具", "run_fishhook_batch.py / run_superelevation_batch.py"],
                ["数据提取工具", "extract_ts.ps1（VSB二进制→CSV自动解析）"],
                ["批量处理脚本", "process_ts_data.m / train_lstm_ts.m / train_cnn_ts.m / train_cnnlstm_ts.m"],
            ].map(([k,v]) => new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 30 },
                children: [new TextRun({ text: k + "：", size: 20, font: "Arial", bold: true }),
                          new TextRun({ text: v, size: 20, font: "Arial" })] })),

            // Final
            new Paragraph({ spacing: { before: 400 }, children: [new PageBreak()] }),
            new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("六、总结与展望")] }),
            new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "本工作成功搭建了TruckSim-MATLAB联合仿真框架，实现了从车辆建模、多工况设计、数据自动提取到侧翻预警模型训练的完整闭环。基于37组真实TruckSim仿真数据（含鱼钩、双移线、阶跃转向及道路横坡）训练的CNN-LSTM模型达到F1=0.969、AUC=0.9988的预测精度，验证了神经网络侧翻预警方法的可行性。", size: 22, font: "Arial"})] }),

            new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: "后续工作建议：", size: 22, font: "Arial", bold: true })] }),
            ...[
                "设计基于差动制动的防侧翻控制器，实现'预警-防控'闭环",
                "实现TruckSim-Simulink实时联合仿真闭环（LDP晃动反馈）",
                "引入UKF状态估计，处理实车传感器噪声问题",
                "将LSTM模型部署为实时侧翻预警系统（MATLAB Coder转C代码）",
                "跨工况泛化验证，提升模型的工程适用性",
            ].map(t => new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 30 },
                children: [new TextRun({ text: t, size: 20, font: "Arial" })] })),
        ]
    }]
});

const outPath = 'C:/Users/LENOVO/OneDrive/桌面/TruckSim联合仿真工作汇报_20260823.docx';
Packer.toBuffer(doc).then(buf => {
    fs.writeFileSync(outPath, buf);
    console.log('Saved: ' + outPath);
}).catch(err => { console.error(err); process.exit(1); });
