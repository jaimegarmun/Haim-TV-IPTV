import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/l10n/l10n.dart';

class EditDialog extends StatefulWidget {
  final Source source;
  final AsyncCallback afterSave;
  final BuildContext parentContext;
  const EditDialog({
    super.key,
    required this.source,
    required this.afterSave,
    required this.parentContext,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: AlertDialog(
          title: Text(tr("Edit source {name}", {"name": widget.source.name})),
          actions: [
            TextButton(
              onPressed: () async {
                if (!_formKey.currentState!.saveAndValidate()) {
                  return;
                }
                Navigator.of(context).pop();
                await Error.tryAsyncNoLoading(
                  () async => await NativeBridge.instance.updateSource(
                    Source(
                      id: widget.source.id,
                      name: widget.source.name,
                      sourceType: widget.source.sourceType,
                      url: _formKey.currentState?.value["url"],
                      username: widget.source.sourceType == SourceType.xtream
                          ? _formKey.currentState?.value["username"]
                          : null,
                      password: widget.source.sourceType == SourceType.xtream
                          ? _formKey.currentState?.value["password"]
                          : null,
                    ),
                  ),
                  widget.parentContext,
                );
                await widget.afterSave();
              },
              child: Text(tr("Save")),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr("Cancel")),
            ),
          ],
          content: FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                FormBuilderTextField(
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  initialValue: widget.source.url,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: tr("This field cannot be empty."),
                    ),
                  ]),
                  decoration: InputDecoration(
                    labelText: tr("URL"),
                    prefixIcon: const Icon(Icons.link),
                    border: const OutlineInputBorder(),
                  ),
                  name: 'url',
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.username,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                      errorText: tr("This field cannot be empty."),
                    ),
                    ]),
                    decoration: InputDecoration(
                      labelText: tr("Username"),
                      prefixIcon: const Icon(Icons.account_circle),
                      border: const OutlineInputBorder(),
                    ),
                    name: 'username',
                  ),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.password,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                      errorText: tr("This field cannot be empty."),
                    ),
                    ]),
                    decoration: InputDecoration(
                      labelText: tr("Password"),
                      prefixIcon: const Icon(Icons.password),
                      border: const OutlineInputBorder(),
                    ),
                    name: 'password',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
